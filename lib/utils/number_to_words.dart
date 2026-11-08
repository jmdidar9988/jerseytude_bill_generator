class NumberToWords {
  static const List<String> _units = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen'
  ];

  static const List<String> _tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
  ];

  static String convert(double amount) {
    final intValue = amount.floor();
    if (intValue == 0) return 'Zero BDT Only.';

    String words = _convertInteger(intValue).trim();
    // Capitalize properly
    return '$words BDT Only.';
  }

  static String _convertInteger(int n) {
    if (n < 0) return 'Minus ${_convertInteger(-n)}';
    if (n < 20) return _units[n];
    if (n < 100) {
      return '${_tens[n ~/ 10]} ${n % 10 != 0 ? _units[n % 10] : ''}';
    }
    if (n < 1000) {
      return '${_units[n ~/ 100]} Hundred ${n % 100 != 0 ? _convertInteger(n % 100) : ''}';
    }
    if (n < 1000000) {
      return '${_convertInteger(n ~/ 1000)} Thousand ${n % 1000 != 0 ? _convertInteger(n % 1000) : ''}';
    }
    if (n < 1000000000) {
      return '${_convertInteger(n ~/ 1000000)} Million ${n % 1000000 != 0 ? _convertInteger(n % 1000000) : ''}';
    }
    return '${_convertInteger(n ~/ 1000000000)} Billion ${n % 1000000000 != 0 ? _convertInteger(n % 1000000000) : ''}';
  }
}

