# SwiftSnapshotTesting

This project's purpose is to simplify UI testing on iOS.

`SwiftSnapshotTesting` helps to check application's UI with a few lines of code. No need to manually manage reference images any more.

This framework is able to:
* take a screenshot of a full screen, screen without status bar or any `XCUIElement` individually
* record the screenshot on your Mac
* compare and highlight the difference between new screenshots and previously recorded ones using [`Metal`](https://developer.apple.com/metal/)

Internally `SwiftSnapshotTesting` operates with [`MTLTextures`](https://developer.apple.com/documentation/metal/mtltexture) during the snapshot comparison. Also it uses [`Resources Bridge Monitor`](ResourcesBridgeMonitor/) app to read and write files on Mac.

⚠️ Currently this project is in early alfa stage and it's a subject for improvements.

## Requirements

* Swift `5.2`
* iOS `11.0`

## Install via [`Cocoapods`](https://cocoapods.org)

```ruby
pod 'SwiftSnapshotTesting'
```

## How To Use

* Create a subclass of `SnapshotTestCase`

  ```Swift
  class MyCoolUITest: SnapshotTestCase { ...
  ```

* Start session and try to connect to `Monitor` automatically

  ```Swift
  bridge.tryToConnect()
  ```

* Choose folder on your Mac to store the reference snapshots by overriding `snapshotsReferencesFolder` variable

  ```Swift
  override var snapshotsReferencesFolder: String {
      "/Path-To-Snapshots-Folder/"
  }
  ```

* Assert any UI element

  ```Swift
  assert(element: XCUIElement,
         testName: String,
         threshold: Float = 10,
         recording: Bool = false) throws
  ```

  * `element` - element to compare
  * `testName` - name of the test. It will be used in the name of the reference image file
  * `threshold` - the threshold used to compare element with its reference image
  * `recording` - by setting `true` this argument you will record the reference snapshot. By setting `false` you will compare the element with previously recorded snapshot.


* Assert screenshot

  ```Swift
  assert(screenshot: XCUIScreenshot,
         testName: String,
         ignoreStatusBar: Bool = true,
         threshold: Float = 10,
         recording: Bool = false) throws
  ```

* Assert any `MTLTexture`

  ```Swift
  assert(texture: MTLTexture,
         testName: String,
         threshold: Float = 10,
         recording: Bool = false) throws
  ```

## Example

Your can find a small [example](https://github.com/eugenebokhan/Image-Flip/blob/master/ImageFlip/ImageFlipUITests/ImageFlipUITests.swift) of usage of `SwiftSnapshotTesting` in my [`ImageFlip`](https://github.com/eugenebokhan/Image-Flip) repo.

# [License](LICENSE)

MIT
