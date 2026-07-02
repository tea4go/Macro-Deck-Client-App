import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom, timeout, catchError, of } from 'rxjs';
import { App } from '@capacitor/app';
import { Filesystem, Directory } from '@capacitor/filesystem';
import { FileOpener } from '@capacitor-community/file-opener';
import { DiagnosticService } from '../diagnostic/diagnostic.service';
import { SettingsService } from '../settings/settings.service';

/** GitHub 仓库（更新源，public 仓库无需 token） */
const GITHUB_OWNER = 'tea4go';
const GITHUB_REPO = 'Macro-Deck-Client-App';
const GITHUB_LATEST_RELEASE_API = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest`;

/** Gitee 仓库（更新源，国内访问更快） */
const GITEE_OWNER = 'tea4go';
const GITEE_REPO = 'Macro-Deck-Client-App';
const GITEE_LATEST_RELEASE_API = `https://gitee.com/api/v5/repos/${GITEE_OWNER}/${GITEE_REPO}/releases/latest`;

/** 检查更新的结果 */
export interface UpdateInfo {
  /** 是否有比当前更新的版本 */
  hasUpdate: boolean;
  /** 远端 versionName（如 3.0.1） */
  versionName: string;
  /** 远端 versionCode（整数） */
  versionCode: number;
  /** APK 下载地址 */
  downloadUrl: string;
  /** 更新说明（release body） */
  releaseNotes: string;
}

/**
 * 应用内更新服务（仅 Android）。
 * 支持 GitHub / Gitee 双源检查，根据用户设置选择更新源。
 * 解析 APK 资产名 MacroDeckClient-<name>-<code>.apk 得远端版本，
 * 与本地 App.getInfo().build 运行时版本号比对；可下载 APK 并触发系统安装器。
 */
@Injectable({
  providedIn: 'root'
})
export class UpdateService {

  constructor(private http: HttpClient,
              private diagnosticService: DiagnosticService,
              private settingsService: SettingsService) { }

  /**
   * 检查是否有新版本（仅 Android 原生平台执行）。
   * @param silent 静默模式（启动时用）：出错或无更新时不抛错，仅返回结果
   * @returns 检查结果；非 Android 或请求失败返回 hasUpdate=false
   */
  async checkForUpdate(silent: boolean = true): Promise<UpdateInfo> {
    const none: UpdateInfo = { hasUpdate: false, versionName: '', versionCode: 0, downloadUrl: '', releaseNotes: '' };

    // 仅 Android 支持应用内更新（iOS 走 App Store，Web 无意义）
    if (!this.diagnosticService.isAndroid()) {
      return none;
    }

    // 根据用户设置选择更新源（默认 gitee，国内访问更快）
    const source = await this.settingsService.getUpdateSource();
    const apiUrl = source === 'gitee' ? GITEE_LATEST_RELEASE_API : GITHUB_LATEST_RELEASE_API;

    // 拉取最新 release（10 秒超时；失败静默）
    const release: any = await firstValueFrom(
      this.http.get(apiUrl).pipe(
        timeout(10000),
        catchError(() => of(null))
      )
    );
    if (!release || !release.assets) {
      return none;
    }

    // 从 apk 资产名解析远端版本：MacroDeckClient-<versionName>-<versionCode>.apk
    const apkAsset = (release.assets as any[]).find(
      a => typeof a.name === 'string' && a.name.toLowerCase().endsWith('.apk')
    );
    if (!apkAsset) {
      return none;
    }
    const parsed = this.parseApkName(apkAsset.name);
    if (!parsed) {
      return none;
    }

    // 运行时读取当前实际安装的 versionCode（而非编译时常量 environment.versionCode），
    // 确保 APK 通过系统安装器更新后能正确识别已升级
    const appInfo = await App.getInfo();
    const installedVersionCode = parseInt(appInfo.build, 10) || 0;
    const info: UpdateInfo = {
      hasUpdate: parsed.versionCode > installedVersionCode,
      versionName: parsed.versionName,
      versionCode: parsed.versionCode,
      downloadUrl: apkAsset.browser_download_url,
      releaseNotes: release.body ?? ''
    };
    return info;
  }

  /**
   * 判断某个更新是否应弹窗提示：有更新，且未被用户「跳过」。
   * @param info checkForUpdate 的结果
   */
  async shouldPrompt(info: UpdateInfo): Promise<boolean> {
    if (!info.hasUpdate) {
      return false;
    }
    const skipped = await this.settingsService.getSkippedVersion();
    return info.versionCode > skipped;
  }

  /**
   * 记住「跳过此版本」，下次不再提示该版本（更新的版本仍会提示）。
   * @param versionCode 要跳过的 versionCode
   */
  async skipVersion(versionCode: number) {
    await this.settingsService.setSkippedVersion(versionCode);
  }

  /**
   * 下载 APK 并触发系统安装器。
   * @param url APK 下载地址
   * @param versionCode 用于命名下载文件
   * @throws 下载或打开失败时抛出，由调用方处理
   */
  async downloadAndInstall(url: string, versionCode: number): Promise<void> {
    const fileName = `MacroDeckClient-update-${versionCode}.apk`;
    // 下载到 Cache 目录（无需额外存储权限）
    const result = await Filesystem.downloadFile({
      url,
      path: fileName,
      directory: Directory.Cache
    });
    // 取绝对路径供 file-opener 打开
    let filePath = result.path;
    if (!filePath) {
      const uri = await Filesystem.getUri({ path: fileName, directory: Directory.Cache });
      filePath = uri.uri;
    }
    // 打开 APK → Android 系统安装器（需 REQUEST_INSTALL_PACKAGES 权限 + 用户授予「安装未知应用」）
    await FileOpener.open({
      filePath,
      contentType: 'application/vnd.android.package-archive'
    });
  }

  /**
   * 解析 APK 资产名 MacroDeckClient-<versionName>-<versionCode>.apk。
   * @param name 资产文件名
   * @returns 解析出的 versionName/versionCode；不匹配返回 null
   */
  private parseApkName(name: string): { versionName: string; versionCode: number } | null {
    const m = name.match(/^MacroDeckClient-(.+)-(\d+)\.apk$/i);
    if (!m) {
      return null;
    }
    return { versionName: m[1], versionCode: parseInt(m[2], 10) };
  }
}
