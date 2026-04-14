import ProjectDescription

let defaultDeploymentTarget: DeploymentTargets = .iOS("18.7")
let signingTeam = Environment.teamId.getString(default: "3VDQ4656LX")
let marketingVersion = Environment.wechoreMarketingVersion.getString(default: "1.0.0")
let buildNumber = Environment.wechoreBuildNumber.getString(default: "1")
let cloudKitEnvironment = Environment.wechoreCloudKitEnvironment.getString(default: "Development")
let currentProjectVersion = {
    let digits = buildNumber.filter(\.isNumber)
    return digits.isEmpty ? "1" : digits
}()

struct WeChoreFlavor {
    let appTargetName: String
    let bundleID: String
    let appGroupID: String
    let cloudKitContainerIdentifier: String
    let displayName: String
    let urlScheme: String
}

let productionFlavor = WeChoreFlavor(
    appTargetName: "WeChore",
    bundleID: "app.peyton.wechore",
    appGroupID: "group.app.peyton.wechore",
    cloudKitContainerIdentifier: "iCloud.app.peyton.wechore",
    displayName: "WeChore",
    urlScheme: "wechore"
)

let developmentFlavor = WeChoreFlavor(
    appTargetName: "WeChoreDev",
    bundleID: "app.peyton.wechore.dev",
    appGroupID: "group.app.peyton.wechore.dev",
    cloudKitContainerIdentifier: "iCloud.app.peyton.wechore.dev",
    displayName: "WeChore Dev",
    urlScheme: "wechore-dev"
)

func flavorBuildSettings(_ flavor: WeChoreFlavor) -> SettingsDictionary {
    [
        "WECHORE_APP_GROUP_ID": .string(flavor.appGroupID),
        "WECHORE_ICLOUD_CONTAINER": .string(flavor.cloudKitContainerIdentifier),
        "WECHORE_ICLOUD_ENVIRONMENT": .string(cloudKitEnvironment),
        "WECHORE_URL_SCHEME": .string(flavor.urlScheme),
        "WECHORE_DISPLAY_NAME": .string(flavor.displayName)
    ]
}

func targetSettings(for flavor: WeChoreFlavor) -> Settings {
    var base = SettingsDictionary()
        .automaticCodeSigning(devTeam: signingTeam)
    base["SWIFT_VERSION"] = "6.0"
    base["IPHONEOS_DEPLOYMENT_TARGET"] = "18.7"
    base["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
    base["ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME"] = "AccentColor"
    for (key, value) in flavorBuildSettings(flavor) {
        base[key] = value
    }
    return .settings(base: base)
}

func appTarget(for flavor: WeChoreFlavor) -> Target {
    .target(
        name: flavor.appTargetName,
        destinations: .iOS,
        product: .app,
        bundleId: flavor.bundleID,
        deploymentTargets: defaultDeploymentTarget,
        infoPlist: .file(path: "Info.plist"),
        sources: [
            "Sources/**"
        ],
        resources: [
            "Resources/**"
        ],
        entitlements: "WeChore.entitlements",
        settings: targetSettings(for: flavor)
    )
}

let project = Project(
    name: "WeChore",
    settings: {
        var base = SettingsDictionary()
            .marketingVersion(marketingVersion)
            .currentProjectVersion(currentProjectVersion)
        base["WECHORE_BUILD_NUMBER"] = .string(buildNumber)
        base["SWIFT_VERSION"] = "6.0"
        return .settings(base: base)
    }(),
    targets: [
        appTarget(for: productionFlavor),
        appTarget(for: developmentFlavor),
        .target(
            name: "WeChoreTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "app.peyton.wechore.tests",
            deploymentTargets: defaultDeploymentTarget,
            infoPlist: .file(path: "Tests.plist"),
            sources: [
                "Tests/**"
            ],
            dependencies: [
                .target(name: productionFlavor.appTargetName)
            ],
            settings: .settings(base: flavorBuildSettings(productionFlavor))
        ),
        .target(
            name: "WeChoreIntegrationTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "app.peyton.wechore.integration-tests",
            deploymentTargets: defaultDeploymentTarget,
            infoPlist: .file(path: "Tests.plist"),
            sources: [
                "IntegrationTests/**"
            ],
            dependencies: [
                .target(name: productionFlavor.appTargetName)
            ],
            settings: .settings(base: flavorBuildSettings(productionFlavor))
        ),
        .target(
            name: "WeChoreUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "app.peyton.wechore.ui-tests",
            deploymentTargets: defaultDeploymentTarget,
            infoPlist: .file(path: "Tests.plist"),
            sources: [
                "UITests/**"
            ],
            dependencies: [
                .target(name: productionFlavor.appTargetName)
            ],
            settings: .settings(base: flavorBuildSettings(productionFlavor))
        )
    ]
)
