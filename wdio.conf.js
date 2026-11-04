/**
 * WebdriverIO config for the mysdworx Android app (Appium + UiAutomator2).
 *
 * Appium is expected on port 4723 (`npm run appium:start`); the appium service
 * below can also start it. Override the target device with DEVICE_UDID.
 */

const capabilities = {
    platformName: 'Android',
    'appium:automationName': 'UiAutomator2',
    'appium:platformVersion': '15',
    'appium:deviceName': 'Android Device',
    'appium:noReset': true,
    'appium:fullReset': false,
    'appium:newCommandTimeout': 300,
    'appium:androidInstallTimeout': 90000,
    'appium:autoGrantPermissions': true,
    'appium:autoAcceptAlerts': true,
    'appium:enablePerformanceLogging': true,
    'appium:printPageSourceOnFindFailure': true,

    // SD Worx Inhouse app
    'appium:appPackage': 'be.sdworx.sdwa.inhouse',
    'appium:appActivity': 'com.sdworx.sdwa.MainActivity',
    'appium:intentAction': 'android.intent.action.MAIN',
    'appium:intentCategory': 'android.intent.category.LAUNCHER',
    'appium:autoLaunch': false
};

if (process.env.DEVICE_UDID) {
    capabilities['appium:udid'] = process.env.DEVICE_UDID;
}

exports.config = {
    runner: 'local',
    port: 4723,
    path: '/',

    specs: ['./tests/**/*.spec.js'],
    exclude: [],
    capabilities: [capabilities],

    logLevel: 'info',
    bail: 0,
    baseUrl: '',
    waitforTimeout: 10000,
    connectionRetryTimeout: 120000,
    connectionRetryCount: 3,

    services: [
        ['appium', {
            command: 'appium',
            args: {
                port: 4723,
                relaxedSecurity: true,
                allowInsecure: ['adb_shell']
            }
        }]
    ],

    framework: 'mocha',
    reporters: ['spec'],
    mochaOpts: {
        ui: 'bdd',
        timeout: 60000
    },

    before: function () {
        driver.setTimeout({ implicit: 5000 });
    }
};
