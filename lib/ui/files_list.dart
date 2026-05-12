import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fz_api_handling/fz_api_handling.dart';
import 'package:wisp/models/file_data.dart';
import 'package:wisp/providers/files.dart';

class FilesList extends ConsumerWidget {
  const FilesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentDirectoryValue = ref.watch(currentDirectory);
    return ApiProviderBuilder(
      provider: directoryList.call(currentDirectoryValue),
      dataBuilder: (context, data) {
        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (context, index) {
            final fileData = data[index];
            return ListTile(
              leading: Icon(fileData is DirectoryData ? Icons.folder : Icons.file_copy),
              title: Text(fileData.filename),
              onTap: () {
                setCurrentDirectory(ref, fileData.path);
              },
            );
          },
        );
      },
    );
  }
}
