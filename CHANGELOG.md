# Thangu Changelog

## [1.0.4] - 2026-04-17
### Added
- **Biometric Authentication**: Fingerprint/Face recognition for app security
- **App Locking**: Automatic re-lock when app goes to background
- **Data Import**: File picker integration for importing JSON backups
- **Smart Savings Automation**: End-of-month surplus automatic distribution to active savings goals
- **Monthly Rollover Tracking**: Prevents duplicate processing across month boundaries
- **Enhanced Dashboard**: Income and expenses displayed side-by-side
- Dependencies: `local_auth` v3.0.1, `file_picker` v8.0.7

### Changed
- MainActivity.kt upgraded to FlutterFragmentActivity for better lifecycle management
- Home screen layout reorganized for better financial overview
- Settings screen with improved import/export interface

### Security
- Added biometric permissions to AndroidManifest.xml
- Optional security toggle in settings for biometric protection

## [1.0.2] - 2026-04-11
### Added
- **Bank Balance Display**: Shows actual total net worth (income - expenses)
- **Persistent Storage**: Balance remains stable across app reopenings
- **QAR Currency Standard**: Unified QAR currency symbol throughout app
- **Mobile Optimization**: Responsive balance font, quick actions layout
- **Month-wise Highlighting**: Recent transactions highlighted with month headers
- **Balance Card Enhancement**: Monthly net displayed on right side of income/expense row
- **Enhanced SMS Detection**: Arabic/English financial keywords, QAR amount patterns
- **MIT License**: Added open-source license

### Fixed
- Corrupted sms_history_service.dart file repair
- Removed duplicate _isFinancialSms() method
- Fixed min() function scoping
- Proper class and method structure with single closing braces

### Changed
- Updated color scheme to modern Indigo/Cyan palette
- Changed internal SMS handling logic
- Improved resource cleanup for stable builds

## [1.0.1] - 2026-03-27
### Added
- Initial SMS transaction processing
- Basic dashboard display
- AI categorization prototypes
- Core models and database


[1.0.2]: https://github.com/henricktomfranco/Thangu/compare/main...release-v1.0.2