import 'ffi/native_file_bindings.dart' as c;

class OpenFlags {
  final int value;
  const OpenFlags(this.value);

  OpenFlags operator |(OpenFlags other) => OpenFlags(value | other.value);

  OpenFlags operator &(OpenFlags other) => OpenFlags(value & other.value);

  bool contains(OpenFlags flag) => (value & flag.value) == flag.value;

  static const readOnly = OpenFlags(c.O_RDONLY);
  static const writeOnly = OpenFlags(c.O_WRONLY);
  static const readWrite = OpenFlags(c.O_RDWR);
  static const create = OpenFlags(c.O_CREAT);
  static const exclusive = OpenFlags(c.O_EXCL);
  static const noCttY = OpenFlags(c.O_NOCTTY);
  static const truncate = OpenFlags(c.O_TRUNC);
  static const append = OpenFlags(c.O_APPEND);
  static const nonblocking = OpenFlags(c.O_NONBLOCK);
  static const syncWrites = OpenFlags(c.O_SYNC);
  static const asyncWrites = OpenFlags(c.O_ASYNC);
  static const directIO = OpenFlags(c.O_DIRECT);
  static const noATime = OpenFlags(c.O_NOATIME);
  static const closeOnExec = OpenFlags(c.O_CLOEXEC);
  static const pathOnly = OpenFlags(c.O_PATH);
  static const tmpFile = OpenFlags(c.O_TMPFILE);
  static const dataSync = OpenFlags(c.O_DSYNC);
  static const directory = OpenFlags(c.O_DIRECTORY);
  static const noFollow = OpenFlags(c.O_NOFOLLOW);

  @override
  String toString() => "$value";

  @override
  int get hashCode => value.hashCode;

  @override
  bool operator ==(Object other) {
    return other is OpenFlags && value == other.value;
  }
}

enum Whence {
  set(c.SEEK_SET),
  current(c.SEEK_CUR),
  hole(c.SEEK_HOLE),
  data(c.SEEK_DATA),
  end(c.SEEK_END);

  final int value;
  const Whence(this.value);
}

const int fGetFD = c.F_GETFD;
const int fSetFD = c.F_SETFD;
const int fGetFL = c.F_GETFL;
const int fSetFL = c.F_SETFL;
const int fDupFD = c.F_DUPFD;
const int fDupFDCloseExec = c.F_DUPFD_CLOEXEC;
const int fdCloseExec = c.FD_CLOEXEC;
const int fGetOwn = c.F_GETOWN;
const int fSetOwn = c.F_SETOWN;
const int fReadLock = c.F_RDLCK;
const int fWriteLock = c.F_WRLCK;
const int fUnlock = c.F_UNLCK;
const int lockShared = c.LOCK_SH;
const int lockExclusive = c.LOCK_EX;
const int lockNonblocking = c.LOCK_NB;
const int lockUnlock = c.LOCK_UN;
const int accessModeMask = c.O_ACCMODE;
const int atFdCwd = c.AT_FDCWD;
const int atSymlinkNoFollow = c.AT_SYMLINK_NOFOLLOW;
const int atSymlinkFollow = c.AT_SYMLINK_FOLLOW;
const int atEmptyPath = c.AT_EMPTY_PATH;
const int fallocKeepSize = 0x01;
const int fallocPunchHole = 0x02;
const int rwHipri = 0x01;
const int rwDSync = 0x02;
const int rwSync = 0x04;
const int rwNoWait = 0x08;
const int rwAppend = 0x10;
