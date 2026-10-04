#!/usr/bin/env python3
"""Regenerate the dependency-free Xcode project. Requires Python 3 only."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parents[1]
project = root / 'LifeLedger.xcodeproj'
project.mkdir(exist_ok=True)
def uid(key): return hashlib.sha256(key.encode()).hexdigest()[:24].upper()
objects = []
def obj(key, body):
    objects.append(f'\t\t{uid(key)} = {{ {body} }};')
    return uid(key)
for name in ['LifeLedger', 'LifeLedgerTests', 'LifeLedgerUITests']:
    obj(name+'Group', f'isa = PBXFileSystemSynchronizedRootGroup; path = {name}; sourceTree = "<group>";')
    typ = 'wrapper.application' if name == 'LifeLedger' else 'wrapper.cfbundle'
    ext = 'app' if name == 'LifeLedger' else 'xctest'
    obj(name+'Product', f'isa = PBXFileReference; explicitFileType = {typ}; includeInIndex = 0; path = {name}.{ext}; sourceTree = BUILT_PRODUCTS_DIR;')
    for phase in ['Sources', 'Frameworks', 'Resources']:
        obj(name+phase, f'isa = PBX{phase}BuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    settings = {'PRODUCT_NAME':'"$(TARGET_NAME)"', 'PRODUCT_BUNDLE_IDENTIFIER':f'com.mrlingan.{name.lower()}', 'SWIFT_VERSION':'5.0', 'IPHONEOS_DEPLOYMENT_TARGET':'17.0', 'TARGETED_DEVICE_FAMILY':'"1,2"', 'GENERATE_INFOPLIST_FILE':'YES', 'CODE_SIGN_STYLE':'Automatic', 'SUPPORTED_PLATFORMS':'"iphoneos iphonesimulator"', 'SWIFT_EMIT_LOC_STRINGS':'YES'}
    if name == 'LifeLedger':
        settings.update({'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon', 'INFOPLIST_KEY_CFBundleDisplayName':'"人生账本"', 'INFOPLIST_KEY_LSApplicationCategoryType':'"public.app-category.lifestyle"', 'INFOPLIST_KEY_NSFaceIDUsageDescription':'"使用 Face ID 解锁你的人生账本。"', 'INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES', 'INFOPLIST_KEY_UILaunchScreen_Generation':'YES', 'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone':'"UIInterfaceOrientationPortrait"', 'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad':'"UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"', 'SWIFT_OBJC_BRIDGING_HEADER':'"LifeLedger/Services/LifeLedger-Bridging-Header.h"', 'OTHER_LDFLAGS':'"$(inherited) -lz"', 'MARKETING_VERSION':'1.0.0', 'CURRENT_PROJECT_VERSION':'1'})
    elif name == 'LifeLedgerTests':
        settings.update({'TEST_HOST':'"$(BUILT_PRODUCTS_DIR)/LifeLedger.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/LifeLedger"', 'BUNDLE_LOADER':'"$(TEST_HOST)"', 'SWIFT_OBJC_BRIDGING_HEADER':'"LifeLedger/Services/LifeLedger-Bridging-Header.h"'})
    else: settings['TEST_TARGET_NAME'] = 'LifeLedger'
    for conf in ['Debug', 'Release']:
        values = dict(settings)
        if conf == 'Debug': values['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = '"DEBUG $(inherited)"'
        obj(name+conf, 'isa = XCBuildConfiguration; buildSettings = { '+' '.join(f'{k} = {v};' for k,v in values.items())+f' }}; name = {conf};')
    obj(name+'Config', f'isa = XCConfigurationList; buildConfigurations = ({uid(name+"Debug")}, {uid(name+"Release")}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    deps = ''
    if name != 'LifeLedger':
        obj(name+'Proxy', f'isa = PBXContainerItemProxy; containerPortal = {uid("Project")}; proxyType = 1; remoteGlobalIDString = {uid("LifeLedgerTarget")}; remoteInfo = LifeLedger;')
        dep = obj(name+'Dependency', f'isa = PBXTargetDependency; target = {uid("LifeLedgerTarget")}; targetProxy = {uid(name+"Proxy")};')
        deps = dep
    producttype = 'com.apple.product-type.application' if name == 'LifeLedger' else 'com.apple.product-type.bundle.unit-test' if name == 'LifeLedgerTests' else 'com.apple.product-type.bundle.ui-testing'
    obj(name+'Target', f'isa = PBXNativeTarget; buildConfigurationList = {uid(name+"Config")}; buildPhases = ({uid(name+"Sources")}, {uid(name+"Frameworks")}, {uid(name+"Resources")}); buildRules = (); dependencies = ({deps}); fileSystemSynchronizedGroups = ({uid(name+"Group")}); name = {name}; packageProductDependencies = (); productName = {name}; productReference = {uid(name+"Product")}; productType = "{producttype}";')
obj('Products', 'isa = PBXGroup; children = ('+', '.join(uid(n+'Product') for n in ['LifeLedger','LifeLedgerTests','LifeLedgerUITests'])+'); name = Products; sourceTree = "<group>";')
obj('Main', 'isa = PBXGroup; children = ('+', '.join(uid(n+'Group') for n in ['LifeLedger','LifeLedgerTests','LifeLedgerUITests'])+f', {uid("Products")}); sourceTree = "<group>";')
for conf in ['Debug','Release']:
    values = {'CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','SDKROOT':'iphoneos','SWIFT_OPTIMIZATION_LEVEL':'"-Onone"' if conf == 'Debug' else '"-O"','ENABLE_TESTABILITY':'YES' if conf == 'Debug' else 'NO','DEBUG_INFORMATION_FORMAT':'dwarf' if conf == 'Debug' else '"dwarf-with-dsym"','GCC_C_LANGUAGE_STANDARD':'gnu17','CLANG_WARN_DOCUMENTATION_COMMENTS':'YES','GCC_WARN_UNINITIALIZED_AUTOS':'YES_AGGRESSIVE'}
    obj('Project'+conf,'isa = XCBuildConfiguration; buildSettings = { '+' '.join(f'{k} = {v};' for k,v in values.items())+f' }}; name = {conf};')
obj('ProjectConfig',f'isa = XCConfigurationList; buildConfigurations = ({uid("ProjectDebug")}, {uid("ProjectRelease")}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('Project',f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2700; TargetAttributes = {{ {uid("LifeLedgerTestsTarget")} = {{ TestTargetID = {uid("LifeLedgerTarget")}; }}; {uid("LifeLedgerUITestsTarget")} = {{ TestTargetID = {uid("LifeLedgerTarget")}; }}; }}; }}; buildConfigurationList = {uid("ProjectConfig")}; compatibilityVersion = "Xcode 16.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, "zh-Hans", Base); mainGroup = {uid("Main")}; preferredProjectObjectVersion = 77; productRefGroup = {uid("Products")}; projectDirPath = ""; projectRoot = ""; targets = ({uid("LifeLedgerTarget")}, {uid("LifeLedgerTestsTarget")}, {uid("LifeLedgerUITestsTarget")});')
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 77;\n\tobjects = {\n'+'\n'.join(objects)+f'\n\t}};\n\trootObject = {uid("Project")};\n}}\n')
scheme = project/'xcshareddata/xcschemes'; scheme.mkdir(parents=True,exist_ok=True)
def ref(name): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(name+"Target")}" BuildableName="{name}.{"app" if name=="LifeLedger" else "xctest"}" BlueprintName="{name}" ReferencedContainer="container:LifeLedger.xcodeproj"/>'
(scheme/'LifeLedger.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref('LifeLedger')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{ref('LifeLedgerTests')}</TestableReference><TestableReference skipped="NO">{ref('LifeLedgerUITests')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref('LifeLedger')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref('LifeLedger')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(project)
