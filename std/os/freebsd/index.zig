const c = @import("../c/index.zig");
const assert = @import("../debug.zig").assert;
const builtin = @import("builtin");
const arch = switch (builtin.arch) {
    builtin.Arch.x86_64 => @import("x86_64.zig"),
    else => @compileError("unsupported arch"),
};
pub use @import("errno.zig");

pub const PATH_MAX = 1024;

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const PROT_NONE = 0;
pub const PROT_READ = 1;
pub const PROT_WRITE = 2;
pub const PROT_EXEC = 4;

pub const MAP_FAILED = @maxValue(usize);
pub const MAP_SHARED = 0x0001;
pub const MAP_PRIVATE = 0x0002;
pub const MAP_FIXED = 0x0010;
pub const MAP_STACK = 0x0400;
pub const MAP_NOSYNC = 0x0800;
pub const MAP_ANON = 0x1000;
pub const MAP_ANONYMOUS = MAP_ANON;
pub const MAP_FILE = 0;
pub const MAP_NORESERVE = 0;

pub const MAP_GUARD = 0x00002000;
pub const MAP_EXCL = 0x00004000;
pub const MAP_NOCORE = 0x00020000;
pub const MAP_PREFAULT_READ = 0x00040000;
pub const MAP_32BIT = 0x00080000;

pub const WNOHANG = 1;
pub const WUNTRACED = 2;
pub const WSTOPPED = WUNTRACED;
pub const WCONTINUED = 4;
pub const WNOWAIT = 8;
pub const WEXITED = 16;
pub const WTRAPPED = 32;

pub const SA_ONSTACK = 0x0001;
pub const SA_RESTART = 0x0002;
pub const SA_RESETHAND = 0x0004;
pub const SA_NOCLDSTOP = 0x0008;
pub const SA_NODEFER = 0x0010;
pub const SA_NOCLDWAIT = 0x0020;
pub const SA_SIGINFO = 0x0040;

pub const SIGHUP = 1;
pub const SIGINT = 2;
pub const SIGQUIT = 3;
pub const SIGILL = 4;
pub const SIGTRAP = 5;
pub const SIGABRT = 6;
pub const SIGIOT = SIGABRT;
pub const SIGEMT = 7;
pub const SIGFPE = 8;
pub const SIGKILL = 9;
pub const SIGBUS = 10;
pub const SIGSEGV = 11;
pub const SIGSYS = 12;
pub const SIGPIPE = 13;
pub const SIGALRM = 14;
pub const SIGTERM = 15;
pub const SIGURG = 16;
pub const SIGSTOP = 17;
pub const SIGTSTP = 18;
pub const SIGCONT = 19;
pub const SIGCHLD = 20;
pub const SIGTTIN = 21;
pub const SIGTTOU = 22;
pub const SIGIO = 23;
pub const SIGXCPU = 24;
pub const SIGXFSZ = 25;
pub const SIGVTALRM = 26;
pub const SIGPROF = 27;
pub const SIGWINCH = 28;
pub const SIGINFO = 29;
pub const SIGUSR1 = 30;
pub const SIGUSR2 = 31;
pub const SIGTHR = 32;
pub const SIGLWP = SIGTHR;
pub const SIGLIBRT = 33;

pub const SIGRTMIN = 65;
pub const SIGRTMAX = 126;

pub const O_RDONLY = 0o0;
pub const O_WRONLY = 0o1;
pub const O_RDWR = 0o2;
pub const O_ACCMODE = 0o3;

pub const O_CREAT = arch.O_CREAT;
pub const O_EXCL = arch.O_EXCL;
pub const O_NOCTTY = arch.O_NOCTTY;
pub const O_TRUNC = arch.O_TRUNC;
pub const O_APPEND = arch.O_APPEND;
pub const O_NONBLOCK = arch.O_NONBLOCK;
pub const O_DSYNC = arch.O_DSYNC;
pub const O_SYNC = arch.O_SYNC;
pub const O_RSYNC = arch.O_RSYNC;
pub const O_DIRECTORY = arch.O_DIRECTORY;
pub const O_NOFOLLOW = arch.O_NOFOLLOW;
pub const O_CLOEXEC = arch.O_CLOEXEC;

pub const O_ASYNC = arch.O_ASYNC;
pub const O_DIRECT = arch.O_DIRECT;
pub const O_LARGEFILE = arch.O_LARGEFILE;
pub const O_NOATIME = arch.O_NOATIME;
pub const O_PATH = arch.O_PATH;
pub const O_TMPFILE = arch.O_TMPFILE;
pub const O_NDELAY = arch.O_NDELAY;

pub const SEEK_SET = 0;
pub const SEEK_CUR = 1;
pub const SEEK_END = 2;

pub const SIG_BLOCK = 1;
pub const SIG_UNBLOCK = 2;
pub const SIG_SETMASK = 3;

pub const SOCK_STREAM = 1;
pub const SOCK_DGRAM = 2;
pub const SOCK_RAW = 3;
pub const SOCK_RDM = 4;
pub const SOCK_SEQPACKET = 5;

pub const SOCK_CLOEXEC = 0x10000000;
pub const SOCK_NONBLOCK = 0x20000000;

// TODO: From here
pub const PROTO_ip = 0o000;
pub const PROTO_icmp = 0o001;
pub const PROTO_igmp = 0o002;
pub const PROTO_ggp = 0o003;
pub const PROTO_ipencap = 0o004;
pub const PROTO_st = 0o005;
pub const PROTO_tcp = 0o006;
pub const PROTO_egp = 0o010;
pub const PROTO_pup = 0o014;
pub const PROTO_udp = 0o021;
pub const PROTO_hmp = 0o024;
pub const PROTO_xns_idp = 0o026;
pub const PROTO_rdp = 0o033;
pub const PROTO_iso_tp4 = 0o035;
pub const PROTO_xtp = 0o044;
pub const PROTO_ddp = 0o045;
pub const PROTO_idpr_cmtp = 0o046;
pub const PROTO_ipv6 = 0o051;
pub const PROTO_ipv6_route = 0o053;
pub const PROTO_ipv6_frag = 0o054;
pub const PROTO_idrp = 0o055;
pub const PROTO_rsvp = 0o056;
pub const PROTO_gre = 0o057;
pub const PROTO_esp = 0o062;
pub const PROTO_ah = 0o063;
pub const PROTO_skip = 0o071;
pub const PROTO_ipv6_icmp = 0o072;
pub const PROTO_ipv6_nonxt = 0o073;
pub const PROTO_ipv6_opts = 0o074;
pub const PROTO_rspf = 0o111;
pub const PROTO_vmtp = 0o121;
pub const PROTO_ospf = 0o131;
pub const PROTO_ipip = 0o136;
pub const PROTO_encap = 0o142;
pub const PROTO_pim = 0o147;
pub const PROTO_raw = 0o377;

pub const PF_UNSPEC = 0;
pub const PF_LOCAL = 1;
pub const PF_UNIX = PF_LOCAL;
pub const PF_FILE = PF_LOCAL;
pub const PF_INET = 2;
pub const PF_AX25 = 3;
pub const PF_IPX = 4;
pub const PF_APPLETALK = 5;
pub const PF_NETROM = 6;
pub const PF_BRIDGE = 7;
pub const PF_ATMPVC = 8;
pub const PF_X25 = 9;
pub const PF_INET6 = 10;
pub const PF_ROSE = 11;
pub const PF_DECnet = 12;
pub const PF_NETBEUI = 13;
pub const PF_SECURITY = 14;
pub const PF_KEY = 15;
pub const PF_NETLINK = 16;
pub const PF_ROUTE = PF_NETLINK;
pub const PF_PACKET = 17;
pub const PF_ASH = 18;
pub const PF_ECONET = 19;
pub const PF_ATMSVC = 20;
pub const PF_RDS = 21;
pub const PF_SNA = 22;
pub const PF_IRDA = 23;
pub const PF_PPPOX = 24;
pub const PF_WANPIPE = 25;
pub const PF_LLC = 26;
pub const PF_IB = 27;
pub const PF_MPLS = 28;
pub const PF_CAN = 29;
pub const PF_TIPC = 30;
pub const PF_BLUETOOTH = 31;
pub const PF_IUCV = 32;
pub const PF_RXRPC = 33;
pub const PF_ISDN = 34;
pub const PF_PHONET = 35;
pub const PF_IEEE802154 = 36;
pub const PF_CAIF = 37;
pub const PF_ALG = 38;
pub const PF_NFC = 39;
pub const PF_VSOCK = 40;
pub const PF_MAX = 41;

pub const AF_UNSPEC = PF_UNSPEC;
pub const AF_LOCAL = PF_LOCAL;
pub const AF_UNIX = AF_LOCAL;
pub const AF_FILE = AF_LOCAL;
pub const AF_INET = PF_INET;
pub const AF_AX25 = PF_AX25;
pub const AF_IPX = PF_IPX;
pub const AF_APPLETALK = PF_APPLETALK;
pub const AF_NETROM = PF_NETROM;
pub const AF_BRIDGE = PF_BRIDGE;
pub const AF_ATMPVC = PF_ATMPVC;
pub const AF_X25 = PF_X25;
pub const AF_INET6 = PF_INET6;
pub const AF_ROSE = PF_ROSE;
pub const AF_DECnet = PF_DECnet;
pub const AF_NETBEUI = PF_NETBEUI;
pub const AF_SECURITY = PF_SECURITY;
pub const AF_KEY = PF_KEY;
pub const AF_NETLINK = PF_NETLINK;
pub const AF_ROUTE = PF_ROUTE;
pub const AF_PACKET = PF_PACKET;
pub const AF_ASH = PF_ASH;
pub const AF_ECONET = PF_ECONET;
pub const AF_ATMSVC = PF_ATMSVC;
pub const AF_RDS = PF_RDS;
pub const AF_SNA = PF_SNA;
pub const AF_IRDA = PF_IRDA;
pub const AF_PPPOX = PF_PPPOX;
pub const AF_WANPIPE = PF_WANPIPE;
pub const AF_LLC = PF_LLC;
pub const AF_IB = PF_IB;
pub const AF_MPLS = PF_MPLS;
pub const AF_CAN = PF_CAN;
pub const AF_TIPC = PF_TIPC;
pub const AF_BLUETOOTH = PF_BLUETOOTH;
pub const AF_IUCV = PF_IUCV;
pub const AF_RXRPC = PF_RXRPC;
pub const AF_ISDN = PF_ISDN;
pub const AF_PHONET = PF_PHONET;
pub const AF_IEEE802154 = PF_IEEE802154;
pub const AF_CAIF = PF_CAIF;
pub const AF_ALG = PF_ALG;
pub const AF_NFC = PF_NFC;
pub const AF_VSOCK = PF_VSOCK;
pub const AF_MAX = PF_MAX;

pub const DT_UNKNOWN = 0;
pub const DT_FIFO = 1;
pub const DT_CHR = 2;
pub const DT_DIR = 4;
pub const DT_BLK = 6;
pub const DT_REG = 8;
pub const DT_LNK = 10;
pub const DT_SOCK = 12;
pub const DT_WHT = 14;

pub const TCGETS = 0x5401;
pub const TCSETS = 0x5402;
pub const TCSETSW = 0x5403;
pub const TCSETSF = 0x5404;
pub const TCGETA = 0x5405;
pub const TCSETA = 0x5406;
pub const TCSETAW = 0x5407;
pub const TCSETAF = 0x5408;
pub const TCSBRK = 0x5409;
pub const TCXONC = 0x540A;
pub const TCFLSH = 0x540B;
pub const TIOCEXCL = 0x540C;
pub const TIOCNXCL = 0x540D;
pub const TIOCSCTTY = 0x540E;
pub const TIOCGPGRP = 0x540F;
pub const TIOCSPGRP = 0x5410;
pub const TIOCOUTQ = 0x5411;
pub const TIOCSTI = 0x5412;
pub const TIOCGWINSZ = 0x5413;
pub const TIOCSWINSZ = 0x5414;
pub const TIOCMGET = 0x5415;
pub const TIOCMBIS = 0x5416;
pub const TIOCMBIC = 0x5417;
pub const TIOCMSET = 0x5418;
pub const TIOCGSOFTCAR = 0x5419;
pub const TIOCSSOFTCAR = 0x541A;
pub const FIONREAD = 0x541B;
pub const TIOCINQ = FIONREAD;
pub const TIOCLINUX = 0x541C;
pub const TIOCCONS = 0x541D;
pub const TIOCGSERIAL = 0x541E;
pub const TIOCSSERIAL = 0x541F;
pub const TIOCPKT = 0x5420;
pub const FIONBIO = 0x5421;
pub const TIOCNOTTY = 0x5422;
pub const TIOCSETD = 0x5423;
pub const TIOCGETD = 0x5424;
pub const TCSBRKP = 0x5425;
pub const TIOCSBRK = 0x5427;
pub const TIOCCBRK = 0x5428;
pub const TIOCGSID = 0x5429;
pub const TIOCGRS485 = 0x542E;
pub const TIOCSRS485 = 0x542F;
pub const TIOCGPTN = 0x80045430;
pub const TIOCSPTLCK = 0x40045431;
pub const TIOCGDEV = 0x80045432;
pub const TCGETX = 0x5432;
pub const TCSETX = 0x5433;
pub const TCSETXF = 0x5434;
pub const TCSETXW = 0x5435;
pub const TIOCSIG = 0x40045436;
pub const TIOCVHANGUP = 0x5437;
pub const TIOCGPKT = 0x80045438;
pub const TIOCGPTLCK = 0x80045439;
pub const TIOCGEXCL = 0x80045440;

fn unsigned(s: i32) u32 {
    return @bitCast(u32, s);
}
fn signed(s: u32) i32 {
    return @bitCast(i32, s);
}
pub fn WEXITSTATUS(s: i32) i32 {
    return signed((unsigned(s) & 0xff00) >> 8);
}
pub fn WTERMSIG(s: i32) i32 {
    return signed(unsigned(s) & 0x7f);
}
pub fn WSTOPSIG(s: i32) i32 {
    return WEXITSTATUS(s);
}
pub fn WIFEXITED(s: i32) bool {
    return WTERMSIG(s) == 0;
}
pub fn WIFSTOPPED(s: i32) bool {
    return (u16)(((unsigned(s) & 0xffff) *% 0x10001) >> 8) > 0x7f00;
}
pub fn WIFSIGNALED(s: i32) bool {
    return (unsigned(s) & 0xffff) -% 1 < 0xff;
}

pub const winsize = extern struct {
    ws_row: u16,
    ws_col: u16,
    ws_xpixel: u16,
    ws_ypixel: u16,
};

/// Get the errno from a syscall return value, or 0 for no error.
pub fn getErrno(r: usize) usize {
    const signed_r = @bitCast(isize, r);
    return if (signed_r > -4096 and signed_r < 0) @intCast(usize, -signed_r) else 0;
}

pub fn dup2(old: i32, new: i32) usize {
    return arch.syscall2(arch.SYS_dup2, usize(old), usize(new));
}

pub fn chdir(path: [*]const u8) usize {
    return arch.syscall1(arch.SYS_chdir, @ptrToInt(path));
}

pub fn execve(path: [*]const u8, argv: [*]const ?[*]const u8, envp: [*]const ?[*]const u8) usize {
    return arch.syscall3(arch.SYS_execve, @ptrToInt(path), @ptrToInt(argv), @ptrToInt(envp));
}

pub fn fork() usize {
    return arch.syscall0(arch.SYS_fork);
}

pub fn getcwd(buf: [*]u8, size: usize) usize {
    return arch.syscall2(arch.SYS___getcwd, @ptrToInt(buf), size);
}

pub fn getdents(fd: i32, dirp: [*]u8, count: usize) usize {
    return arch.syscall3(arch.SYS_getdents, usize(fd), @ptrToInt(dirp), count);
}

pub fn isatty(fd: i32) bool {
    var wsz: winsize = undefined;
    return arch.syscall3(arch.SYS_ioctl, @intCast(usize, fd), TIOCGWINSZ, @ptrToInt(&wsz)) == 0;
}

pub fn readlink(noalias path: [*]const u8, noalias buf_ptr: [*]u8, buf_len: usize) usize {
    return arch.syscall3(arch.SYS_readlink, @ptrToInt(path), @ptrToInt(buf_ptr), buf_len);
}

pub fn mkdir(path: [*]const u8, mode: u32) usize {
    return arch.syscall2(arch.SYS_mkdir, @ptrToInt(path), mode);
}

pub fn mmap(address: ?*u8, length: usize, prot: usize, flags: usize, fd: i32, offset: isize) usize {
    return arch.syscall6(arch.SYS_mmap, @ptrToInt(address), length, prot, flags, @intCast(usize, fd), @bitCast(usize, offset));
}

pub fn munmap(address: usize, length: usize) usize {
    return arch.syscall2(arch.SYS_munmap, address, length);
}

pub fn read(fd: i32, buf: [*]u8, count: usize) usize {
    return arch.syscall3(arch.SYS_read, @intCast(usize, fd), @ptrToInt(buf), count);
}

pub fn rmdir(path: [*]const u8) usize {
    return arch.syscall1(arch.SYS_rmdir, @ptrToInt(path));
}

pub fn symlink(existing: [*]const u8, new: [*]const u8) usize {
    return arch.syscall2(arch.SYS_symlink, @ptrToInt(existing), @ptrToInt(new));
}

pub fn pread(fd: i32, buf: [*]u8, count: usize, offset: usize) usize {
    return arch.syscall4(arch.SYS_pread, usize(fd), @ptrToInt(buf), count, offset);
}

pub fn pipe(fd: *[2]i32) usize {
    return pipe2(fd, 0);
}

pub fn pipe2(fd: *[2]i32, flags: usize) usize {
    return arch.syscall2(arch.SYS_pipe2, @ptrToInt(fd), flags);
}

pub fn write(fd: i32, buf: [*]const u8, count: usize) usize {
    return arch.syscall3(arch.SYS_write, @intCast(usize, fd), @ptrToInt(buf), count);
}

pub fn pwrite(fd: i32, buf: [*]const u8, count: usize, offset: usize) usize {
    return arch.syscall4(arch.SYS_pwrite, @intCast(usize, fd), @ptrToInt(buf), count, offset);
}

pub fn rename(old: [*]const u8, new: [*]const u8) usize {
    return arch.syscall2(arch.SYS_rename, @ptrToInt(old), @ptrToInt(new));
}

pub fn open(path: [*]const u8, flags: u32, perm: usize) usize {
    return arch.syscall3(arch.SYS_open, @ptrToInt(path), flags, perm);
}

pub fn create(path: [*]const u8, perm: usize) usize {
    return arch.syscall2(arch.SYS_creat, @ptrToInt(path), perm);
}

pub fn openat(dirfd: i32, path: [*]const u8, flags: usize, mode: usize) usize {
    return arch.syscall4(arch.SYS_openat, @intCast(usize, dirfd), @ptrToInt(path), flags, mode);
}

pub fn close(fd: i32) usize {
    return arch.syscall1(arch.SYS_close, @intCast(usize, fd));
}

pub fn lseek(fd: i32, offset: isize, ref_pos: usize) usize {
    return arch.syscall3(arch.SYS_lseek, @intCast(usize, fd), @bitCast(usize, offset), ref_pos);
}

pub fn exit(status: i32) noreturn {
    _ = arch.syscall1(arch.SYS_exit, @bitCast(usize, isize(status)));
    unreachable;
}

pub fn arc4rand(buf: [*]u8, count: usize, reseed: bool) void {
    c.arc4rand(@ptrCast(&c_void, buf), c_uint(count), c_int(reseed));
}

pub fn kill(pid: i32, sig: i32) usize {
    return arch.syscall2(arch.SYS_kill, @bitCast(usize, @intCast(isize, pid)), @intCast(usize, sig));
}

pub fn unlink(path: [*]const u8) usize {
    return arch.syscall1(arch.SYS_unlink, @ptrToInt(path));
}

pub fn waitpid(pid: i32, status: *i32, options: i32) usize {
    return arch.syscall4(arch.SYS_wait4, @bitCast(usize, isize(pid)), @ptrToInt(status), @bitCast(usize, isize(options)), 0);
}

pub fn nanosleep(req: *const timespec, rem: ?*timespec) usize {
    return arch.syscall2(arch.SYS_nanosleep, @ptrToInt(req), @ptrToInt(rem));
}

pub fn setuid(uid: u32) usize {
    return arch.syscall1(arch.SYS_setuid, uid);
}

pub fn setgid(gid: u32) usize {
    return arch.syscall1(arch.SYS_setgid, gid);
}

pub fn setreuid(ruid: u32, euid: u32) usize {
    return arch.syscall2(arch.SYS_setreuid, ruid, euid);
}

pub fn setregid(rgid: u32, egid: u32) usize {
    return arch.syscall2(arch.SYS_setregid, rgid, egid);
}

pub fn sigprocmask(flags: u32, noalias set: *const sigset_t, noalias oldset: ?*sigset_t) usize {
    // TODO: Implement
    return 0;
}

pub fn sigaction(sig: u6, noalias act: *const Sigaction, noalias oact: ?*Sigaction) usize {
    // TODO: Implement
    return 0;
}

const NSIG = 65;
const sigset_t = [128 / @sizeOf(usize)]usize;
const all_mask = []usize{@maxValue(usize)};
const app_mask = []usize{0xfffffffc7fffffff};

/// Renamed from `sigaction` to `Sigaction` to avoid conflict with the syscall.
pub const Sigaction = struct {
    // TODO: Adjust to use freebsd struct layout
    handler: extern fn (i32) void,
    mask: sigset_t,
    flags: u32,
};

pub const SIG_ERR = @intToPtr(extern fn (i32) void, @maxValue(usize));
pub const SIG_DFL = @intToPtr(extern fn (i32) void, 0);
pub const SIG_IGN = @intToPtr(extern fn (i32) void, 1);
pub const empty_sigset = []usize{0} ** sigset_t.len;

pub fn raise(sig: i32) usize {
    // TODO implement, see linux equivalent for what we want to try and do
    return 0;
}

fn blockAllSignals(set: *sigset_t) void {
    // TODO implement
}

fn blockAppSignals(set: *sigset_t) void {
    // TODO implement
}

fn restoreSignals(set: *sigset_t) void {
    // TODO implement
}

pub fn sigaddset(set: *sigset_t, sig: u6) void {
    const s = sig - 1;
    (*set)[usize(s) / usize.bit_count] |= usize(1) << (s & (usize.bit_count - 1));
}

pub fn sigismember(set: *const sigset_t, sig: u6) bool {
    const s = sig - 1;
    return ((*set)[usize(s) / usize.bit_count] & (usize(1) << (s & (usize.bit_count - 1)))) != 0;
}

pub const Stat = arch.Stat;
pub const timespec = arch.timespec;

pub fn fstat(fd: i32, stat_buf: *Stat) usize {
    return arch.syscall2(arch.SYS_fstat, @intCast(usize, fd), @ptrToInt(stat_buf));
}
