# SplitCheck

A native iOS app for splitting dinner bills easily. Scan a receipt, itemize costs, share a QR code with your table, and let everyone pay their fair share via Venmo.

## Features

- **Receipt Scanning** — Take a photo or choose from your library. Apple Vision framework extracts text and parses items + prices automatically.
- **Item Review & Editing** — Review scanned items, edit names/prices, add missing items, adjust tax and tip.
- **QR Code Sharing** — Generate a QR code that encodes the full session. Others scan it to join — no account or server needed.
- **Item Selection** — Guests select only the items they ordered. Items can be split between multiple people.
- **Smart Totals** — Tax and tip are proportionally distributed based on each person's items.
- **Venmo Integration** — One-tap payment via Venmo deep link with pre-filled amount and recipient.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Setup

### Option A: XcodeGen (recommended)

1. Install XcodeGen if you haven't already:
   ```bash
   brew install xcodegen
   ```

2. Generate the Xcode project:
   ```bash
   cd SplitCheck
   xcodegen generate
   ```

3. Open `SplitCheck.xcodeproj` in Xcode.

### Option B: Manual Xcode project

1. Open Xcode and create a new iOS App project named "SplitCheck" with SwiftUI.
2. Delete the auto-generated files and drag in the contents of the `SplitCheck/` folder.
3. Set deployment target to iOS 17.0.
4. Add the camera and photo library usage descriptions to Info.plist.

### Then:

4. Set your development team in Signing & Capabilities.
5. Build and run on a physical device (camera features require a real device).

## Architecture

```
SplitCheck/
├── App/
│   └── SplitCheckApp.swift          # App entry point
├── Models/
│   ├── ReceiptItem.swift            # Individual line item
│   └── SplitSession.swift           # Full session with items, tax, tip
├── Views/
│   ├── ContentView.swift            # Home screen + navigation
│   ├── CameraCaptureView.swift      # Camera / photo picker
│   ├── ReceiptEditView.swift        # Review + edit parsed items
│   ├── HostSetupView.swift          # Enter name, Venmo, tip
│   ├── ShareSessionView.swift       # QR code display
│   ├── ScanQRView.swift             # QR code scanner (guests)
│   ├── ItemSelectionView.swift      # Guests select their items
│   └── PaymentSummaryView.swift     # Total breakdown + Venmo button
├── Services/
│   ├── OCRService.swift             # Vision framework text recognition
│   ├── ReceiptParser.swift          # Parses OCR output into items
│   └── QRCodeService.swift          # QR code generation + decoding
└── Extensions/
    └── Color+Theme.swift            # App color theme
```

## How It Works

### For the person paying (Host):
1. Open the app → tap "Scan Receipt"
2. Take a photo or choose from your library
3. Review the parsed items, edit as needed
4. Enter your name, Venmo username, and desired tip
5. Share the generated QR code with your table

### For everyone else (Guests):
1. Open the app → tap "Scan QR Code"
2. Scan the QR code shown by the host
3. Enter your name
4. Select the items you ordered
5. Review your total (with proportional tax & tip)
6. Tap to pay via Venmo

## Notes

- The QR code encodes the full session data, so no server or internet connection is needed for sharing.
- Venmo deep linking requires Venmo to be installed on the device. If not installed, it falls back to the Venmo website.
- Camera features require a physical device — they won't work in the iOS Simulator.
