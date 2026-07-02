import { Injectable } from '@angular/core';
import {App} from "@capacitor/app";
import {Platform} from "@ionic/angular";
import {Device} from "@capacitor/device";
import {environment} from "../../../environments/environment";

/** 诊断服务，提供应用版本信息和设备平台检测功能 */
@Injectable({
  providedIn: 'root'
})
export class DiagnosticService {

  constructor(private platform: Platform) { }

  /**
   * 获取应用版本号字符串
   * 原生平台返回原生包版本，Web 平台返回与 Android 一致的「版本名+构建号」
   * @returns 版本号字符串
   */
  async getVersion() {
    if (this.isiOSorAndroid()) {
      const info = await App.getInfo();
      // 拼接 versionName.versionCode，如 "3.0.1.7"
      return `v. ${this.versionPrefix()}-${info.version}.${info.build}`;
    }

    // Web 平台：显示与 Android build.gradle 同步的版本（由 Sync-AppVersion 写入 environment）
    return `v${environment.version}.${environment.versionCode}`;
  }

  /**
   * 检测当前是否为 Android Oreo（8.x，SDK 26/27）
   * Android Oreo 不支持屏幕方向锁定功能
   * @returns 是否为 Android Oreo
   */
  async isAndroidOreo() {
    if (!this.isAndroid()) {
      return false;
    }

    let androidSdk = await this.getAndroidSdkVersion();
    return androidSdk == 26 || androidSdk == 27;
  }

  /**
   * 获取 Android SDK 版本号
   * @returns Android SDK 版本号
   */
  async getAndroidSdkVersion() {
    const info = await Device.getInfo();
    return info.androidSDKVersion;
  }

  /**
   * 检测当前是否为 Android 平台
   * @returns 是否为 Android
   */
  public isAndroid() {
    return this.platform.is("android");
  }

  /**
   * 检测当前是否为 iOS 平台
   * @returns 是否为 iOS
   */
  public isiOS() {
    return this.platform.is("ios");
  }

  /**
   * 获取版本号前缀标识
   * Android 为 "a"，iOS 为 "i"，其他为 "pwa"
   * @returns 版本前缀字符串
   */
  private versionPrefix(): string {
    if (this.isAndroid()) {
      return "a";
    } else if (this.isiOS()) {
      return "i";
    }

    return "pwa";
  }

  /**
   * 检测当前是否为 iOS 或 Android 原生平台
   * @returns 是否为原生移动平台
   */
  public isiOSorAndroid() {
    return this.isiOS() || this.isAndroid();
  }
}
