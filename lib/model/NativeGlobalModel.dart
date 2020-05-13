import 'dart:io';

import 'package:docker_register_cloud/model/GlobalModel.dart';
import 'package:docker_register_cloud/model/TransportModel.dart';
import 'package:docker_register_cloud/repository.dart';
import 'package:clippy/server.dart' as clipy;
import 'package:url_launcher/url_launcher.dart';

class NativeGlobalModel extends GlobalModel {
  @override
  Future<String> link(String repository, String digest) async {
    return Repository(config, auth).link(digest);
  }

  @override
  Future<List<FileItem>> items(String repository) async {
    print(repository);
    return Repository(config, auth).list();
  }

  @override
  Future<void> download(
      String repository, digest, name, TransportModel transport) async {
    var target = (Platform.environment['HOME'] ??
            Platform.environment['USERPROFILE'] ??
            ".") +
        "/Downloads";
    if (Platform.isAndroid) {
      target = "/sdcard/Download";
    }
    var targetPath = "$target/$repository/$name";
    if (!await File(targetPath).parent.exists()) {
      File(targetPath).parent.create(recursive: true);
    }
    Repository(config, auth).pull(
        digest,
        targetPath,
        ModelDownloadTransportProgressListener(
            "$repository:$name", transport, targetPath));
  }

  @override
  Future<void> upload(
      String repository, name, path, TransportModel transport) async {
    Repository repo = Repository(config, auth);
    Translation translation = await repo.begin();
    await repo.upload(
        translation,
        name,
        path,
        ModelUploadTransportProgressListener(
            "$repository:$name", path, transport));
    await repo.commit(translation);
  }

  @override
  Future<void> login(
      String repository, String username, String password) async {
    await auth.login(repository, username, password);
  }

  @override
  void writeClipy(String content) async {
    clipy.write(content);
  }

  @override
  Future<void> open(String path) {
    String parent = path.substring(0, path.lastIndexOf("/"));
    launch("file://$parent");
  }
}

GlobalModel instanceOfGlobalModel() => NativeGlobalModel();

class ModelDownloadTransportProgressListener extends TransportProgressListener {
  final String name;
  final TransportModel transportModel;
  int start;

  ModelDownloadTransportProgressListener(
      this.name, this.transportModel, String path) {
    this.start = DateTime.now().millisecondsSinceEpoch;
    transportModel.createItem(name, path, TransportItemType.DOWNLOAD);
  }

  @override
  void onProgess(int current, int total) {
    transportModel.updateItem(
        name, current, total, TransportStateType.TRANSPORTING);
  }

  @override
  void onSuccess(int total) {
    transportModel.updateItem(name, total, total, TransportStateType.COMPLETED);
  }
}

class ModelUploadTransportProgressListener extends TransportProgressListener {
  final String name;
  final TransportModel transportModel;
  int start;

  ModelUploadTransportProgressListener(
      this.name, String path, this.transportModel) {
    this.start = DateTime.now().millisecondsSinceEpoch;
    transportModel.createItem(name, path, TransportItemType.UPLOAD);
  }

  @override
  void onProgess(int current, int total) {
    transportModel.updateItem(
        name, current, total, TransportStateType.TRANSPORTING);
  }

  @override
  void onSuccess(int total) {
    transportModel.updateItem(name, total, total, TransportStateType.COMPLETED);
  }
}
