import 'dart:convert';

/// Gera o "Pix Copia e Cola" (BR Code estático, padrão EMV do Banco Central).
/// Montado localmente no aparelho; nada é transmitido.
class Pix {
  /// Chave Pix aleatória (EVP) do recebedor.
  static const String chave = 'f74458dc-2a36-49bd-9250-1cef4365ebb8';
  static const String recebedor = 'CARLOS EDUARDO';
  static const String cidade = 'MOGI DAS CRUZES';

  static String _campo(String id, String valor) {
    final tam = valor.length.toString().padLeft(2, '0');
    return '$id$tam$valor';
  }

  /// CRC16-CCITT (polinômio 0x1021, init 0xFFFF).
  static String _crc16(String payload) {
    var crc = 0xFFFF;
    for (final b in utf8.encode(payload)) {
      crc ^= b << 8;
      for (var i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = (crc << 1) ^ 0x1021;
        } else {
          crc <<= 1;
        }
        crc &= 0xFFFF;
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  /// Monta o código Pix copia e cola (sem valor definido).
  static String copiaECola({
    String chavePix = chave,
    String nome = recebedor,
    String municipio = cidade,
  }) {
    final mai = _campo(
      '26',
      _campo('00', 'br.gov.bcb.pix') + _campo('01', chavePix),
    );
    final adicional = _campo('62', _campo('05', '***'));

    final payload = StringBuffer()
      ..write(_campo('00', '01'))
      ..write(_campo('01', '11'))
      ..write(mai)
      ..write(_campo('52', '0000'))
      ..write(_campo('53', '986'))
      ..write(_campo('58', 'BR'))
      ..write(_campo('59', nome))
      ..write(_campo('60', municipio))
      ..write(adicional)
      ..write('6304');

    return '${payload.toString()}${_crc16(payload.toString())}';
  }
}
