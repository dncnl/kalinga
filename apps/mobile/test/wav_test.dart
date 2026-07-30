import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/wav.dart';

void main() {
  test('wrapPcmAsWav produces a 44-byte header followed by the PCM data unchanged', () {
    final pcm = Uint8List.fromList(List.generate(100, (i) => i % 256));

    final wav = wrapPcmAsWav(pcm, sampleRate: 16000, numChannels: 1);

    expect(wav.length, 44 + pcm.length);
    expect(wav.sublist(44), pcm);
  });

  test('RIFF/WAVE/fmt/data chunk ids are correct ASCII', () {
    final wav = wrapPcmAsWav(Uint8List(10), sampleRate: 16000, numChannels: 1);
    String ascii(int start, int len) => String.fromCharCodes(wav.sublist(start, start + len));

    expect(ascii(0, 4), 'RIFF');
    expect(ascii(8, 4), 'WAVE');
    expect(ascii(12, 4), 'fmt ');
    expect(ascii(36, 4), 'data');
  });

  test('header fields match the Google Speech-to-Text LINEAR16 config (16kHz, mono, 16-bit)', () {
    final pcm = Uint8List(2000);
    final wav = wrapPcmAsWav(pcm, sampleRate: 16000, numChannels: 1);
    final view = ByteData.sublistView(wav);

    expect(view.getUint32(4, Endian.little), 36 + pcm.length); // RIFF chunk size
    expect(view.getUint32(16, Endian.little), 16); // fmt chunk size
    expect(view.getUint16(20, Endian.little), 1); // PCM format code
    expect(view.getUint16(22, Endian.little), 1); // numChannels
    expect(view.getUint32(24, Endian.little), 16000); // sampleRate
    expect(view.getUint16(34, Endian.little), 16); // bitsPerSample
    expect(view.getUint32(40, Endian.little), pcm.length); // data chunk size
  });

  test('byteRate and blockAlign are derived correctly for a stereo, 16-bit stream', () {
    final wav = wrapPcmAsWav(Uint8List(4), sampleRate: 44100, numChannels: 2);
    final view = ByteData.sublistView(wav);

    // byteRate = sampleRate * numChannels * bitsPerSample/8
    expect(view.getUint32(28, Endian.little), 44100 * 2 * 2);
    // blockAlign = numChannels * bitsPerSample/8
    expect(view.getUint16(32, Endian.little), 4);
  });

  test('handles empty PCM data without throwing', () {
    final wav = wrapPcmAsWav(Uint8List(0), sampleRate: 16000, numChannels: 1);
    expect(wav.length, 44);
  });
}
