enum ScanFilter {
  original,
  auto,
  blackWhite,
  grayscale,
  lighten,
}

extension ScanFilterLabel on ScanFilter {
  String get label {
    switch (this) {
      case ScanFilter.original:
        return 'Original';
      case ScanFilter.auto:
        return 'Auto';
      case ScanFilter.blackWhite:
        return 'B/W';
      case ScanFilter.grayscale:
        return 'Gray';
      case ScanFilter.lighten:
        return 'Lighten';
    }
  }
}
