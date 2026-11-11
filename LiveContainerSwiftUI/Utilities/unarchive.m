#import "unarchive.h"

#include "archive.h"
#include "archive_entry.h"

static int
copy_data(struct archive *ar, struct archive *aw, NSProgress *progress)
{
  int r;
  const void *buff;
  size_t size;
  la_int64_t offset;

  for (;;) {
    r = archive_read_data_block(ar, &buff, &size, &offset);
    if (r == ARCHIVE_EOF)
      return (ARCHIVE_OK);
    if (r < ARCHIVE_OK)
      return (r);
    r = archive_write_data_block(aw, buff, size, offset);
    if (r < ARCHIVE_OK) {
      fprintf(stderr, "%s\n", archive_error_string(aw));
      return (r);
    }
    progress.completedUnitCount += size;
  }
}

/* Whether one of the parts of `path`, split at "/", is "..". */
static BOOL
has_dot_dot_component(const char *path)
{
  for (const char *part = path;;) {
    const char *end = strchr(part, '/');
    size_t length = end ? (size_t)(end - part) : strlen(part);
    if (length == 2 && part[0] == '.' && part[1] == '.')
      return (YES);
    if (end == NULL)
      return (NO);
    part = end + 1;
  }
}

/* Whether `path` names the folder it is unpacked in itself: every part of it,
 * split at "/", is empty or ".", as in "", "/", "." and "./". */
static BOOL
names_root(const char *path)
{
  for (const char *part = path;;) {
    const char *end = strchr(part, '/');
    size_t length = end ? (size_t)(end - part) : strlen(part);
    if (length > 1 || (length == 1 && part[0] != '.'))
      return (NO);
    if (end == NULL)
      return (YES);
    part = end + 1;
  }
}

/* Whether an entry could write outside the folder it is unpacked in: a name
 * with "..", anything but a plain folder where the folder itself is, a hard
 * link, which can name any file on disk, or a symbolic link that points
 * anywhere but down from where it is. libarchive makes a symbolic link
 * whenever an entry names a target, whatever its type, so every target is
 * checked. A link that only points down keeps every later entry written
 * through it inside the folder too. */
static BOOL
could_escape(struct archive_entry *entry)
{
  const char *pathname = archive_entry_pathname(entry);
  const char *linkTarget = archive_entry_symlink(entry);
  if (pathname == NULL || has_dot_dot_component(pathname))
    return (YES);
  if (names_root(pathname) && (archive_entry_filetype(entry) != AE_IFDIR || linkTarget != NULL))
    return (YES);
  if (archive_entry_hardlink(entry) != NULL)
    return (YES);
  if (archive_entry_filetype(entry) == AE_IFLNK && linkTarget == NULL)
    return (YES);
  if (linkTarget != NULL && (linkTarget[0] == '\0' || linkTarget[0] == '/' || has_dot_dot_component(linkTarget)))
    return (YES);
  return (NO);
}

/* Whether an entry is something an app is made of: a file, a folder or a
 * symbolic link. A device or a FIFO never is, and a FIFO left in the app
 * would keep whatever opens it waiting for ever, as reading the app's
 * Info.plist on the main thread does. */
static BOOL
is_app_entry(struct archive_entry *entry)
{
  switch (archive_entry_filetype(entry)) {
  case AE_IFREG:
  case AE_IFDIR:
  case AE_IFLNK:
    return (YES);
  default:
    return (NO);
  }
}

int extract(NSString* fileToExtract, NSString* extractionPath, NSProgress* progress)
{
    struct archive *a;
    struct archive *ext;
    struct archive_entry *entry;
    int flags;
    int r;

    /* Restore only the times and permissions an app needs. File flags or
     * ACLs from an archive, which pax and xar can carry, could stop
     * zContainer deleting what it unpacked, and so could a mode that locks
     * zContainer out, which the loop takes off each entry first. */
    flags = ARCHIVE_EXTRACT_TIME;
    flags |= ARCHIVE_EXTRACT_PERM;
    /* Also refuse entries whose path has "..", as the loop does first. */
    flags |= ARCHIVE_EXTRACT_SECURE_NODOTDOT;

    // Calculate decompressed size
    a = archive_read_new();
    archive_read_support_format_all(a);
    archive_read_support_filter_all(a);
    if ((r = archive_read_open_filename(a, fileToExtract.fileSystemRepresentation, 10240))) {
        archive_read_free(a);
        return 1;
    }
    while ((r = archive_read_next_header(a, &entry)) != ARCHIVE_EOF) {
        if (r < ARCHIVE_OK)
            fprintf(stderr, "%s\n", archive_error_string(a));
        if (r < ARCHIVE_WARN) {
            archive_read_close(a);
            archive_read_free(a);
            return 1;
        }
        progress.totalUnitCount += archive_entry_size(entry);
    }
    archive_read_close(a);
    archive_read_free(a);

    // Re-open the archive and extract
    a = archive_read_new();
    archive_read_support_format_all(a);
    archive_read_support_filter_all(a);
    if ((r = archive_read_open_filename(a, fileToExtract.fileSystemRepresentation, 10240))) {
        archive_read_free(a);
        return 1;
    }
    ext = archive_write_disk_new();
    archive_write_disk_set_options(ext, flags);
    archive_write_disk_set_standard_lookup(ext);

    // Set when an entry is refused or unpacking stops partway, so a partly
    // unpacked app isn't installed.
    int failed = 0;
    while ((r = archive_read_next_header(a, &entry)) != ARCHIVE_EOF) {
        // Each entry's path strings go when the entry is done, not when the
        // whole IPA is.
        @autoreleasepool {
            if (r < ARCHIVE_OK)
                fprintf(stderr, "%s\n", archive_error_string(a));
            if (r < ARCHIVE_WARN) {
                failed = 1;
                break;
            }

            // An entry that could write outside the unpack folder, such as into
            // another app's files, one that isn't a file, a folder or a
            // symbolic link, or one whose name isn't UTF-8, stops the whole IPA.
            const char *entryName = archive_entry_pathname(entry);
            NSString* currentFile = (could_escape(entry) || !is_app_entry(entry)) ? nil : [NSString stringWithUTF8String:entryName];
            if (currentFile == nil) {
                fprintf(stderr, "refusing %s\n", entryName ?: "an unnamed entry");
                failed = 1;
                break;
            }
            NSString* fullOutputPath = [extractionPath stringByAppendingPathComponent:currentFile];
            //printf("extracting %@ to %@\n", currentFile, fullOutputPath);
            archive_entry_set_pathname(entry, fullOutputPath.fileSystemRepresentation);

            // zContainer can always read and write what it unpacks, and look
            // in and change its folders, whatever modes the archive gives, so
            // it can move the app out and delete the rest. libarchive applies
            // an entry's mode, minus the umask, even without
            // ARCHIVE_EXTRACT_PERM. Setuid, setgid and sticky bits go too.
            if (archive_entry_filetype(entry) != AE_IFLNK) {
                mode_t ownerAccess = archive_entry_filetype(entry) == AE_IFDIR ? 0700 : 0600;
                archive_entry_set_perm(entry, (archive_entry_perm(entry) & 0777) | ownerAccess);
            }

            // A header that can't be written, such as on a full disk or where a
            // file and a folder share a name, leaves the entry out, so it stops
            // the whole IPA too.
            r = archive_write_header(ext, entry);
            if (r < ARCHIVE_OK)
                fprintf(stderr, "%s\n", archive_error_string(ext));
            if (r < ARCHIVE_WARN) {
                failed = 1;
                break;
            }
            if (archive_entry_size(entry) > 0) {
                r = copy_data(a, ext, progress);
                if (r < ARCHIVE_OK)
                    fprintf(stderr, "%s\n", archive_error_string(ext));
                if (r < ARCHIVE_WARN) {
                    failed = 1;
                    break;
                }
            }
            r = archive_write_finish_entry(ext);
            if (r < ARCHIVE_OK)
                fprintf(stderr, "%s\n", archive_error_string(ext));
            if (r < ARCHIVE_WARN) {
                failed = 1;
                break;
            }
        }
    }
    archive_read_close(a);
    archive_read_free(a);
    archive_write_close(ext);
    archive_write_free(ext);

    return failed;
}
