import 'dart:io';
import 'dart:math';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:gpth/utils.dart';

/// Abstract of a *media* - a photo or video
/// Main thing is the [file] - this should not change
///
/// [size] and [hash] getter are here because we can easily cache
///
/// [dateTakenAccuracy] is a number used to compare with other [Media]. When
/// you find a duplicate, use one that has lower [dateTakenAccuracy] number.
/// this and [dateTaken] should either both be null or both filled
class Media {
  /// First file with media, used in early stage when albums are not merged
  ///
  /// BE AWARE OF HOW YOU USE IT
  File get firstFile => files.values.first;

  /// Map between albums and files of same given media
  ///
  /// This is heavily mutated - at first, media from year folders have this
  /// with single null key, and those from albums have one name.
  /// Then, they are merged into one by algos etc.
  ///
  /// At the end of the script, this will have *all* locations of given media,
  /// so that we can safely:
  /// ```dart
  /// // photo.runtimeType == Media;
  /// photo.files[null].move('output/one-big/');  // null is for year folders
  /// photo.files[<album_name>].move('output/albums/<album_name>/');
  /// ```
  Map<String?, File> files;

  // cache
  int? _size;

  /// will be used for finding duplicates/albums
  int get size => _size ??= firstFile.lengthSync();

  /// DateTaken from any source
  DateTime? dateTaken;

  /// higher the worse
  int? dateTakenAccuracy;

  //cache
  Digest? _hash;

  /// will be used for finding duplicates/albums
  /// WARNING: Returns same value for files > [maxFileSize]
  Digest get hash {
    if (_hash != null) return _hash!;
    if (firstFile.lengthSync() > maxFileSize) {
      if (enforceMaxFileSize) {
        //if we enforce max file size, we return a hash of 0
        _hash = Digest(<int>[0]);
      } else if (alternateHash){
        //if we use alternate hash, we use quickHash
        //this is a quick hash that uses only first and last 50% of the file
        _hash = quickHash(firstFile);
      } else {
        //if we don't enforce max file size, we use sha256
        _hash = sha256.convert(firstFile.readAsBytesSync());
      }
    } else {
      _hash = sha256.convert(firstFile.readAsBytesSync());
    }
    return _hash!;
  }
  
  Digest quickHash(File file) {
      //chunk size is 50% of maxFileSize
      int chunkSize = maxFileSize ~/2;
      final raf = file.openSync();
      final head = raf.readSync(chunkSize);
      raf.setPositionSync(max(0, file.lengthSync() - chunkSize));
      final tail = raf.readSync(chunkSize);
      raf.closeSync();

      // create a sha256 hash from the head and tail
      // using AccumulatorSink to avoid memory issues with large files
      final acc = AccumulatorSink<Digest>();
      final sink = sha256.startChunkedConversion(acc);
      sink.add(head);
      sink.add(tail);
      sink.close();

      return acc.events.single;
  }     

  Media(
    this.files, {
    this.dateTaken,
    this.dateTakenAccuracy,
  });

  @override
  String toString() => 'Media('
      '$firstFile, '
      'dateTaken: $dateTaken'
      '${files.keys.length > 1 ? ', albums: ${files.keys}' : ''}'
      ')';
}
