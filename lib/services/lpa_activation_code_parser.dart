class LpaActivationCode {
  const LpaActivationCode({
    required this.raw,
    required this.version,
    required this.smdpAddress,
    required this.matchingId,
    required this.confirmationCode,
  });

  final String raw;
  final String version;
  final String smdpAddress;
  final String? matchingId;
  final String? confirmationCode;
}

class LpaActivationCodeParser {
  const LpaActivationCodeParser._();

  static LpaActivationCode parse(String input) {
    final raw = input.trim();
    final parts = raw.split(r'$');
    if (!raw.toUpperCase().startsWith('LPA:') || parts.length < 2) {
      throw const FormatException('不是有效的 LPA eSIM 激活码');
    }

    final version = parts.first.substring(4);
    final smdpAddress = parts[1].trim();
    if (version.isEmpty || smdpAddress.isEmpty) {
      throw const FormatException('LPA eSIM 激活码缺少版本或 SM-DP+ 地址');
    }

    return LpaActivationCode(
      raw: raw,
      version: version,
      smdpAddress: smdpAddress,
      matchingId: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
      confirmationCode: parts.length > 3 && parts[3].isNotEmpty
          ? parts[3]
          : null,
    );
  }
}
