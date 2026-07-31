import 'dart:typed_data';

/// Wraps raw 16-bit PCM samples in a standard RIFF/WAVE header. Needed
/// because `record`'s streaming API (used so voice-log recording works on
/// web too — see prototype_log_page.dart) hands back headerless PCM
/// chunks, not a ready-made .wav file; the container has to be built
/// after the fact once the total length is known.
Uint8List wrapPcmAsWav(
  Uint8List pcmData, {
  required int sampleRate,
  required int numChannels,
  int bitsPerSample = 16,
}) {
  final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
  final blockAlign = numChannels * bitsPerSample ~/ 8;
  final dataLength = pcmData.length;

  final header = ByteData(44);
  void writeAscii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  writeAscii(0, 'RIFF');
  header.setUint32(4, 36 + dataLength, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // fmt chunk size
  header.setUint16(20, 1, Endian.little); // PCM format
  header.setUint16(22, numChannels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, blockAlign, Endian.little);
  header.setUint16(34, bitsPerSample, Endian.little);
  writeAscii(36, 'data');
  header.setUint32(40, dataLength, Endian.little);

  final wav = BytesBuilder();
  wav.add(header.buffer.asUint8List());
  wav.add(pcmData);
  return wav.toBytes();
}
