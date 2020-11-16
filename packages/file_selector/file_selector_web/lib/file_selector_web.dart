import 'dart:async';
import 'dart:html';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:file_selector_platform_interface/src/web_helpers/web_helpers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:meta/meta.dart';

final String _kFileSelectorInputsDomId = '__file_selector_web_file_input';

/// The web implementation of [FileSelectorPlatform].
///
/// This class implements the `package:file_selector` functionality for the web.
class FileSelectorPlugin extends FileSelectorPlatform {
  Element _target;
  final FileSelectorPluginTestOverrides _overrides;

  bool get _hasTestOverrides => _overrides != null;

  /// Open file dialog for loading files and return a XFile
  @override
  Future<XFile> openFile({
    List<XTypeGroup> acceptedTypeGroups,
    String initialDirectory,
    String confirmButtonText,
  }) async {
    return (await _openFileHelper(false, acceptedTypeGroups)).first;
  }

  /// Open file dialog for loading files and return a XFile
  @override
  Future<List<XFile>> openFiles({
    List<XTypeGroup> acceptedTypeGroups,
    String initialDirectory,
    String confirmButtonText,
  }) async {
    return _openFileHelper(true, acceptedTypeGroups);
  }

  @override
  Future<String> getSavePath({
    List<XTypeGroup> acceptedTypeGroups,
    String initialDirectory,
    String suggestedName,
    String confirmButtonText,
  }) async =>
      null;

  @override
  Future<String> getDirectoryPath({
    String initialDirectory,
    String confirmButtonText,
  }) async =>
      null;

  /// Load Helper
  Future<List<XFile>> _openFileHelper(
      bool multiple, List<XTypeGroup> acceptedTypes) {
    final acceptedTypeString = _getStringFromFilterGroup(acceptedTypes);

    final FileUploadInputElement element =
        createFileInputElement(acceptedTypeString, multiple);

    _target.children.clear();
    addElementToContainerAndClick(_target, element);

    return getFilesWhenReady(element);
  }

  /// Default constructor, initializes _target to a DOM element that we can use
  /// to host HTML elements.
  /// overrides parameter allows for testing to override functions
  FileSelectorPlugin({
    @visibleForTesting FileSelectorPluginTestOverrides overrides,
  }) : _overrides = overrides {
    _target = ensureInitialized(_kFileSelectorInputsDomId);
  }

  /// Registers this class as the default instance of [FileSelectorPlatform].
  static void registerWith(Registrar registrar) {
    FileSelectorPlatform.instance = FileSelectorPlugin();
  }

  /// Convert list of XTypeGroups to a comma-separated string
  String _getStringFromFilterGroup(List<XTypeGroup> acceptedTypes) {
    List<String> allTypes = List();

    for (XTypeGroup group in acceptedTypes ?? []) {
      assert(
          !((group.extensions == null || group.extensions.isEmpty) &&
              (group.mimeTypes == null || group.mimeTypes.isEmpty) &&
              (group.webWildCards == null || group.webWildCards.isEmpty)),
          'At least one of extensions / mimeTypes / webWildCards is required for web.');

      allTypes.addAll(group.extensions
          .map((ext) => ext.isNotEmpty && ext[0] != '.' ? '.' + ext : ext));
      allTypes.addAll(group.mimeTypes ?? []);
      allTypes.addAll(group.webWildCards ?? []);
    }
    return allTypes?.where((e) => e.isNotEmpty)?.join(',') ?? '';
  }

  /// Creates a file input element with only the accept attribute
  @visibleForTesting
  FileUploadInputElement createFileInputElement(
      String accepted, bool multiple) {
    if (_hasTestOverrides && _overrides.createFileInputElement != null) {
      return _overrides.createFileInputElement(accepted, multiple);
    }

    final FileUploadInputElement element = FileUploadInputElement();
    if (accepted.isNotEmpty) {
      element.accept = accepted;
    }
    element.multiple = multiple;

    return element;
  }

  List<XFile> _getXFilesFromFiles(List<File> files) {
    List<XFile> xFiles = List<XFile>();

    for (File file in files) {
      String url = Url.createObjectUrl(file);
      String name = file.name;
      int length = file.size;
      int modified = file.lastModified;

      DateTime modifiedDate = DateTime.fromMillisecondsSinceEpoch(modified);

      xFiles.add(
          XFile(url, name: name, lastModified: modifiedDate, length: length));
    }

    return xFiles;
  }

  /// Getter for retrieving files from an input element
  @visibleForTesting
  List<File> getFilesFromInputElement(InputElement element) {
    if (_hasTestOverrides && _overrides.getFilesFromInputElement != null) {
      return _overrides.getFilesFromInputElement(element);
    }

    return element?.files ?? [];
  }

  /// Listen for file input element to change and retrieve files when
  /// this happens.
  @visibleForTesting
  Future<List<XFile>> getFilesWhenReady(InputElement element) {
    if (_hasTestOverrides && _overrides.getFilesWhenReady != null) {
      return _overrides.getFilesWhenReady(element);
    }

    final Completer<List<XFile>> _completer = Completer();

    // Listens for element change
    element.onChange.first.then((event) {
      // File type from dart:html class
      final List<File> files = getFilesFromInputElement(element);

      // Create XFile from dart:html Files
      final xFiles = _getXFilesFromFiles(files);

      _completer.complete(xFiles);
    });

    element.onError.first.then((event) {
      ErrorEvent error = event;
      _completer.completeError(
          PlatformException(code: error.type, message: error.message));
    });

    return _completer.future;
  }
}

/// Overrides some functions to allow testing
@visibleForTesting
class FileSelectorPluginTestOverrides {
  /// For overriding the creation of the file input element.
  Element Function(String accepted, bool multiple) createFileInputElement;

  /// For overriding retrieving a file from the input element.
  List<File> Function(InputElement input) getFilesFromInputElement;

  /// For overriding waiting for the files to be ready. Useful for testing so we do not hang here.
  Future<List<XFile>> Function(InputElement input) getFilesWhenReady;

  /// Constructor for test override class
  FileSelectorPluginTestOverrides(
      {this.createFileInputElement,
      this.getFilesFromInputElement,
      this.getFilesWhenReady});
}
