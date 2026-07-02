// 开发环境配置文件
// 构建时可通过 angular.json 中的 fileReplacements 替换为生产环境版本

export const environment = {
  /** 是否为生产环境 */
  production: false,
  /** 是否为 Web 版本（非原生应用） */
  webVersion: false,
  /** 应用版本号（= Android versionName，由 Sync-AppVersion 从 build.gradle 同步） */
  version: "3.0.1",
  /** 应用构建号（= Android versionCode，由 Sync-AppVersion 从 build.gradle 同步） */
  versionCode: 9,
};

/*
 * 在开发模式下可导入以下文件以忽略 zone 相关的错误堆栈帧
 * 生产模式下应注释掉此导入，因为会影响错误抛出时的性能
 */
// import 'zone.js/plugins/zone-error';  // Included with Angular CLI.
// This file can be replaced during build by using the `fileReplacements` array.
// `ng build` replaces `environment.ts` with `environment.prod.ts`.
// The list of file replacements can be found in `angular.json`.
