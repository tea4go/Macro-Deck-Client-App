import { Injectable } from '@angular/core';
import {Storage} from "@ionic/storage";
import {ScreenOrientationType} from "../../enums/screen-orientation-type";
import {AppearanceType} from "../../enums/appearance-type";
import {ButtonWidgetBorderStyle} from "../../widget-content-components/button-widget/button-widget-border-style";
import {LanguageType} from "../../enums/language-type";

// 本地存储键名常量
const clientIdStorageKey: string = "client_id";
const wakeLockKey: string = "wake_lock_enabled";
const buttonLongPressDelay: string = "button_long_press_delay";
const screenOrientationKey: string = "screen_orientation";
const connectionCountKey: string = "connection_count";
const lastConnectionKey: string = "last_connection";
const skipSslValidationKey: string = "skip_ssl_validation";
const showMenuButtonKey: string = "show_menu_button";
const appearanceKey: string = "appearance";
const usbAutoConnectKey: string = "usb_auto_connect";
const usbPortKey: string = "usb_port";
const usbUseSslKey: string = "usb_use_ssl";
const buttonWidgetBorderStyleKey: string = "button_widget_border_style";
const languageKey: string = "language";
const skippedUpdateVersionKey: string = "skipped_update_version";

/** 设置服务，管理应用各项配置的持久化存取 */
@Injectable({
  providedIn: 'root'
})
export class SettingsService {


  constructor(private storage: Storage) {
  }

  /**
   * 设置用户选择「跳过」的更新版本号（versionCode）
   * @param versionCode 被跳过的版本的 versionCode
   */
  public async setSkippedVersion(versionCode: number) {
    await this.storage.set(skippedUpdateVersionKey, versionCode);
  }

  /**
   * 获取用户已跳过的更新版本号（versionCode）
   * @returns 已跳过的 versionCode，默认 0（表示未跳过任何版本）
   */
  public async getSkippedVersion(): Promise<number> {
    return await this.storage.get(skippedUpdateVersionKey) ?? 0;
  }

  /**
   * 设置界面语言
   * @param language 语言类型
   */
  public async setLanguage(language: LanguageType) {
    await this.storage.set(languageKey, language);
  }

  /**
   * 获取界面语言
   * @returns 默认 System（跟随系统）
   */
  public async getLanguage(): Promise<LanguageType> {
    return await this.storage.get(languageKey) ?? LanguageType.System;
  }

  /**
   * 设置按钮微件边框样式
   * @param style 边框样式
   */
  public async setButtonWidgetBorderStyle(style: ButtonWidgetBorderStyle) {
    await this.storage.set(buttonWidgetBorderStyleKey, style);
  }

  /**
   * 获取按钮微件边框样式
   * @returns 边框样式，默认为 None（无边框）
   */
  public async getButtonWidgetBorderStyle() {
    return  await this.storage.get(buttonWidgetBorderStyleKey) ?? ButtonWidgetBorderStyle.None;
  }

  /**
   * 设置 USB 连接是否使用 SSL
   * @param useSsl 是否使用 SSL
   */
  public async setUsbUseSsl(useSsl: boolean) {
    await this.storage.set(usbUseSslKey, useSsl);
  }

  /**
   * 获取 USB 连接是否使用 SSL
   * @returns 默认 false
   */
  public async getUsbUseSsl() {
    return  await this.storage.get(usbUseSslKey) ?? false;
  }

  /**
   * 设置 USB 连接端口号
   * @param usbPort 端口号
   */
  public async setUsbPort(usbPort: number) {
    await this.storage.set(usbPortKey, usbPort);
  }

  /**
   * 获取 USB 连接端口号
   * @returns 默认 8191
   */
  public async getUsbPort() {
    return  await this.storage.get(usbPortKey) ?? 8191;
  }

  /**
   * 设置 USB 是否自动连接
   * @param usbAutoConnect 是否自动连接
   */
  public async setUsbAutoConnect(usbAutoConnect: boolean) {
    await this.storage.set(usbAutoConnectKey, usbAutoConnect);
  }

  /**
   * 获取 USB 是否自动连接
   * @returns 默认 false
   */
  public async getUsbAutoConnect() {
    return  await this.storage.get(usbAutoConnectKey) ?? false;
  }

  /**
   * 设置外观主题类型
   * @param appearanceType 外观类型
   */
  public async setAppearance(appearanceType: AppearanceType) {
    await this.storage.set(appearanceKey, appearanceType);
  }

  /**
   * 获取外观主题类型
   * @returns 默认 Dark（深色主题）
   */
  public async getAppearance() {
    return  await this.storage.get(appearanceKey) ?? AppearanceType.Dark;
  }

  /**
   * 设置是否显示菜单按钮
   * @param showMenuButton 是否显示
   */
  public async setShowMenuButton(showMenuButton: boolean) {
    await this.storage.set(showMenuButtonKey, showMenuButton);
  }

  /**
   * 获取是否显示菜单按钮
   * @returns 默认 true
   */
  public async getShowMenuButton() {
    return await this.storage.get(showMenuButtonKey) ?? true;
  }

  /**
   * 设置是否跳过 SSL 证书验证
   * @param lastConnection 是否跳过
   */
  public async setSkipSslValidation(lastConnection: boolean) {
    await this.storage.set(skipSslValidationKey, lastConnection);
  }

  /**
   * 获取是否跳过 SSL 证书验证
   * @returns 默认 false
   */
  public async getSkipSslValidation() {
    return await this.storage.get(skipSslValidationKey) ?? false;
  }

  /**
   * 设置上次连接的服务器 id
   * @param lastConnection 连接 id
   */
  public async setLastConnection(lastConnection: String) {
    await this.storage.set(lastConnectionKey, lastConnection);
  }

  /**
   * 获取上次连接的服务器 id
   * @returns 连接 id 或 undefined
   */
  public async getLastConnection() {
    return await this.storage.get(lastConnectionKey);
  }

  /**
   * 设置屏幕方向
   * @param screenOrientation 屏幕方向类型
   */
  public async setScreenOrientation(screenOrientation: ScreenOrientationType) {
    await this.storage.set(screenOrientationKey, screenOrientation);
  }

  /**
   * 获取屏幕方向设置
   * @returns 默认 Auto（自动旋转）
   */
  public async getScreenOrientation() {
    return  await this.storage.get(screenOrientationKey) ?? ScreenOrientationType.Auto;
  }

  /**
   * 设置按钮长按延迟时间
   * @param delay 延迟时间（毫秒）
   */
  public async setButtonLongPressDelay(delay: number) {
    await this.storage.set(buttonLongPressDelay, delay);
  }

  /**
   * 获取按钮长按延迟时间
   * @returns 默认 1000 毫秒
   */
  public async getButtonLongPressDelay() {
    return await this.storage.get(buttonLongPressDelay) ?? 1000;
  }

  /**
   * 设置屏幕常亮是否启用
   * @param state 是否启用
   */
  public async setWakeLockEnabled(state: boolean) {
    await this.storage.set(wakeLockKey, state);
  }

  /**
   * 获取屏幕常亮是否启用
   * @returns 默认 false
   */
  public async getWakeLockEnabled() {
    return await this.storage.get(wakeLockKey) ?? false;
  }

  /**
   * 获取累计连接次数
   * @returns 连接次数，默认 0
   */
  public async getConnectionCount() {
    return await this.storage.get(connectionCountKey) ?? 0;
  }

  /**
   * 累加连接次数计数器
   */
  public async increaseConnectionCount() {
    let connectionCount = await this.getConnectionCount();
    await this.storage.set(connectionCountKey, connectionCount + 1);
  }

  /**
   * 获取客户端唯一标识符
   * 如果不存在则自动生成
   * @returns 客户端 ID 字符串
   */
  public async getClientId() {
    await this.generateClientId();
    return this.storage.get(clientIdStorageKey);
  }

  /**
   * 生成客户端唯一标识符（仅在不存在时生成）
   * 使用随机字母数字字符串作为 ID
   */
  private async generateClientId() {
    let clientId = await this.storage.get(clientIdStorageKey);
    if (clientId?.length > 0) {
      return;
    }

    clientId = Math.random().toString(36).substring(2, 9);
    await this.storage.set(clientIdStorageKey, clientId);
  }
}
