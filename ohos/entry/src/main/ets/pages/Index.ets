import { FlutterEntry, FlutterPage, FlutterView } from '@ohos/flutter_ohos';

@Entry
@Component
struct Index {
  private flutterEntry?: FlutterEntry;
  private flutterView?: FlutterView;

  aboutToAppear() {
    this.flutterEntry = new FlutterEntry(getContext(this));
    this.flutterEntry.aboutToAppear();
    this.flutterView = this.flutterEntry.getFlutterView();
  }

  aboutToDisappear() {
    this.flutterEntry?.aboutToDisappear();
  }

  onPageShow() {
    this.flutterEntry?.onPageShow();
  }

  onPageHide() {
    this.flutterEntry?.onPageHide();
  }

  build() {
    Column() {
      FlutterPage({ viewId: this.flutterView?.getId() })
        .width('100%')
        .height('100%')
    }
  }
}
