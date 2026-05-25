import 'dart:io';

import 'package:args/args.dart';
import 'package:ffigen/ffigen.dart';
import 'package:ffigen/src/code_generator/native_type.dart';
import 'package:logging/logging.dart';

String _findClangIncludePath() {
  final result = Process.runSync('clang', ['-print-resource-dir']);
  if (result.exitCode != 0) {
    throw Exception('Error: clang not found.');
  }

  final resourceDir = (result.stdout as String).trim();
  if (resourceDir.isEmpty) {
    throw Exception('Warning: clang -print-resource-dir returned empty.');
  }

  final includePath = '$resourceDir/include';
  if (!Directory(includePath).existsSync()) {
    throw Exception("Clang include path does not exists");
  }
  print('Using clang include path: $includePath');
  return includePath;
}

void main(List<String> args) {
  final parser = ArgParser();
  parser.addOption(
    'clang-include',
    abbr: 'I',
    help: 'Path to clang include directory (e.g. /usr/lib/clang/22/include)',
    defaultsTo: '',
  );

  final results = parser.parse(args);

  String clangInclude = results['clang-include'] as String;
  if (clangInclude.isEmpty) {
    clangInclude = _findClangIncludePath();
  }

  final compilerOpts = <String>['-D_GNU_SOURCE'];
  if (clangInclude.isNotEmpty) {
    compilerOpts.add('-I$clangInclude');
  }

  final generator = FfiGenerator(
    headers: Headers(
      entryPoints: [
        Uri.file('/usr/include/fcntl.h'),
        Uri.file('/usr/include/unistd.h'),
        Uri.file('/usr/include/sys/stat.h'),
        Uri.file('/usr/include/errno.h'),
        Uri.file('/usr/include/string.h'),
      ],
      compilerOptions: compilerOpts,
    ),
    output: Output(
      dartFile: Uri.file('lib/src/ffi/native_file_bindings.dart'),
      style: DynamicLibraryBindings(wrapperName: 'NativeFileBindings'),
      sort: true,
      format: true,
    ),
    functions: Functions(
      rename: (decl) =>
          decl.originalName == "__errno_location" ? "errno_location" : decl.originalName,
      include: Declarations.includeSet({
        'open',
        'openat',
        'fcntl',
        'posix_fallocate',
        'fallocate',
        'read',
        'write',
        'close',
        'lseek',
        'fsync',
        'fdatasync',
        'dup',
        'dup2',
        'dup3',
        'pread',
        'pwrite',
        'ftruncate',
        'truncate',
        'stat',
        'fstat',
        'lstat',
        'fstatat',
        'mkdir',
        'mkdirat',
        'copy_file_range',
        'strerror',
        '__errno_location',
      }),
      varArgs: {
        'open': [
          VarArgFunction('', [NativeType(SupportedNativeType.uint32)]),
        ],
        'openat': [
          VarArgFunction('', [NativeType(SupportedNativeType.uint32)]),
        ],
        'fcntl': [
          VarArgFunction('', [NativeType(SupportedNativeType.int32)]),
        ],
      },
    ),
    structs: Structs.includeSet({'stat', 'timespec'}),
    macros: Macros(
      include: (Declaration decl) {
        return _macroPatterns.any((re) => re.hasMatch(decl.originalName));
      },
    ),
  );

  generator.generate(
    logger: Logger.detached('ffigen')
      ..level = Level.ALL
      ..onRecord.listen((record) {
        print('${record.level.name}: ${record.message}');
      }),
  );

  print('Bindings generated.');
}

final _macroPatterns = <RegExp>[
  RegExp(r'^O_'),
  RegExp(r'^AT_'),
  RegExp(r'^F_(GET|SET)(FD|FL|OWN)'),
  RegExp(r'^FD_CLOEXEC$'),
  RegExp(r'^FALLOC_FL_'),
  RegExp(r'^RWF_'),
  RegExp(r'^SPLICE_F_'),
  RegExp(r'^SEEK_'),
  RegExp(r'^R_OK$'),
  RegExp(r'^W_OK$'),
  RegExp(r'^X_OK$'),
  RegExp(r'^F_OK$'),
  RegExp(r'^S_'),
  RegExp(r'^ALLPERMS$'),
  RegExp(r'^DEFFILEMODE$'),
  RegExp(r'^ACCESSPERMS$'),
  RegExp(r'^E[A-Z]'),
  RegExp(r'^F_DUPFD(_CLOEXEC)?$'),
  RegExp(r'^F_RDLCK$'),
  RegExp(r'^F_WRLCK$'),
  RegExp(r'^F_UNLCK$'),
  RegExp(r'^F_EXLCK$'),
  RegExp(r'^F_SHLCK$'),
  RegExp(r'^LOCK_SH$'),
  RegExp(r'^LOCK_EX$'),
  RegExp(r'^LOCK_NB$'),
  RegExp(r'^LOCK_UN$'),
  RegExp(r'^FAPPEND$'),
  RegExp(r'^FFSYNC$'),
  RegExp(r'^FASYNC$'),
  RegExp(r'^FNONBLOCK$'),
  RegExp(r'^FNDELAY$'),
  RegExp(r'^POSIX_FADV_'),
];
