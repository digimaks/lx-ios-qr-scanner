# QRCodeScannerPackage

QR code scanning for iOS, with built-in recognition of credential
issuance and presentation URI schemes.

It is one of the Swift packages used by **Digimaks**, a mobile digital wallet
continuing the work of the
[NOBID Consortium](https://www.nobidconsortium.com/) (the Nordic-Baltic eID
Project), one of the EU Large Scale Pilots preparing for eIDAS 2.0.

## Background

This package is the continuation of
[nobid-lsp-latvia/lx-ios-qr-scanner](https://github.com/nobid-lsp-latvia/lx-ios-qr-scanner),
developed within the NOBID Consortium and carried forward under the name
**Digimaks**.

## Requirements

- iOS 15+
- Swift 5.9+ / Xcode 15+

## Installation

Add the package to your `Package.swift`:

```swift
.package(url: "<repository-url>", from: "1.0.0")
```

or add it in Xcode via **File → Add Package Dependencies…**.

## Overview

| Type | Responsibility |
| ---- | -------------- |
| `QRScannerManager` | Camera session lifecycle (`setUp`, `runSession`, `stopSession`) and metadata capture |
| `QRCodeActionDelegate` | Delivers decoded payloads and scanning errors to the host |
| `CredentialOfferIssuanceScheme` | OpenID4VCI credential-offer schemes |
| `OpenIDPresentationScheme` | OpenID4VP presentation-request schemes |
| `ScanningError` | Camera permission and session failures |

The host app must declare `NSCameraUsageDescription` in its `Info.plist`.

## Licence

Licensed under the [EUPL-1.2](LICENSE). See [Notice](Notice) for attribution.
