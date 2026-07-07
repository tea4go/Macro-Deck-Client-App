import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.suchbyte.macrodeck',
  appName: 'Macro Deck Client',
  webDir: 'www',
  server: {
    androidScheme: 'http'
  },
  // 临时诊断开启，验证完再恢复默认
  loggingBehavior: 'production',
  ios: {
    scheme: 'Macro Deck Client'
  }
};

export default config;
