# 测试体系（TIM防撤回）

本项目遵循三层验收，三者不可互相替代：

| 层级 | 执行位置 | 能证明什么 | 不能证明什么 |
|---|---|---|---|
| **① 源码测试** | `tests/`，本地或 CI `test` job | 结构、命名、plist、配置域、功能源码断言 | 不能证明能编译、能运行 |
| **② Actions 构建** | GitHub Actions `build` job | Theos 编译通过、deb 结构/架构/布局正确 | 不能证明真机行为正确 |
| **③ 真机验收** | 越狱设备手动 | 实际效果、崩溃、性能 | 不可自动化，需人工记录 |

## 快速开始

```sh
python3 scripts/toolchain.py static  # 锁、manifest、workflow 与 wrapper 一致性
python3 tests/run_tests.py            # 全部源码测试，生成 report.txt
python3 tests/run_tests.py -v         # 详细输出
python3 tests/verify_deb.py --project . packages/*.deb   # 按 manifest 核验产物
# CI 还会传 --scheme 和 --expected-version 校验本次构建目标
```

报告文件：`tests/report.txt`（含时间戳，声明只代表源码层）；跳过项不计为通过。
工程根 `toolchain-lock.json` 是本工程受控工具版本和哈希的依据，生成来源为 skill 的 `assets/toolchain-lock.json`，
由 `tweak.json.toolchain_lock` 引用。SDK 目录/target 为 `16.5`，实际 metadata 为 `16.4`，两者分别核验。
本地先人工准备与锁一致的 macOS/Xcode、源码和打包工具，再执行 `python3 scripts/toolchain.py verify`；
PATH 或版本错误会失败，`build.sh` 在任何 make 前执行 verify。`prepare` 的安装/替换已有 Keg 仅允许 GitHub-hosted runner，
不会在个人电脑自动卸载工具。`receipt` 在已有 deb 后生成包含锁 hash、环境、源码及产物证据的 JSON。

## 文件职责

| 文件 | 职责 | 自动覆盖 |
|---|---|---|
| `test_structure.py` | 必需文件、control 元数据、注入过滤器、Makefile hook 库、模板 token 残留、命名前缀 | 全部工程 |
| `test_features.py` | 核心 hook、偏好监听、日志、面板卡片样式、SF Symbols、滑条，以及**插件专属功能** | 通用部分自动，专属部分需追加 |
| `source_checks.py`、`test_source_checks.py` | 去注释检查与路径、空实现、字符串伪装等反向用例 | 全部工程 |
| `test_toolchain.py` | 临时工程中调用生产脚本；锁/环境漂移、verify 顺序、checksum、receipt 白名单；真实本地 Git/子模块/SDK 变异，平台与 receipt 命令使用 mock | 全部工程；无工作流或缺 Git 的相关项明确 skip |
| `test_packaging_headers.py` | 调用实际打包检查器区分 Java CAFEBABE 与 thin/fat Mach-O，拒绝截断/空 fat | 全部工程；不等于 bottle 安装审计 |
| `verify_deb.py` | 预期包名/版本/scheme、精确依赖、布局、Filter、面板与真实 Mach-O 切片范围 | 构建产物 |
| `test_deb_validation.py` | 正确合成容器与错误架构、缺文件、损坏切片等坏包反向用例 | 全部工程 |
| `run_tests.py` | 统一入口与报告；通过、失败、跳过分别计数 | — |

工具链回归只使用标准库，不依赖 PyYAML，不访问远端仓库。mock 不证明真实 macOS/Xcode、Swift 混编或真机可用。

## 迭代纪律（硬规则）

1. **新增或修复任何功能，必须同时补对应的回归测试**：插件功能写在 `test_features.py`，工具链或打包检查器写在对应独立测试中。
   判据：本次改动涉及的每一个行为，都要有一条「改坏了就会失败」的断言；只在注释里留下关键字符串不得通过。
2. 只有 `test` job 全绿，`build` job 才会执行；构建前必须通过工具链 verify，deb 构建后还要通过 `verify_deb.py` 和 receipt 才会上传。
3. 测试脚本、工作流随源码一起提交，不允许只改代码不补测试。
4. 每轮迭代保留测试记录：CI 上传 `test-report` artifact 并在 job summary 显示。
5. 汇报时必须区分：**源码测试通过 / Actions 构建通过 / 已真机验收**，不得混为一谈。

## 补测试的三种常见写法

以下是静态结构断言，`hook_source()` 已去除注释。每项关键检查再做一次删除/改坏实现的反向验证；纯关键词不能证明运行时行为，算法尽量抽出可执行逻辑测试。验包器检查静态容器和结构，签名有效性、系统依赖可用性与实际注入另行验证。

### 新增设置项

```python
def test_new_option_exists(self):
    items = plistlib.loads((PREFS / "Resources" / (PREFIX + "Root.plist")).read_bytes())["items"]
    self.assertTrue(any(i.get("key") == "myNewKey" for i in items))

def test_new_option_consumed(self):
    self.assertIn("myNewKey", hook_source())
```

### 新增功能/动画

```python
def test_new_effect_implemented(self):
    self.assertIn("playMyEffect", hook_source())
```

### 删除功能（防回归）

```python
def test_removed_feature_stays_removed(self):
    self.assertNotIn("playRemoved", hook_source())
```

## CI 门禁链路

```
test (Linux ubuntu-24.04, Python 3.13.14)
  ├─ toolchain.py static
  └─ run_tests.py
        ↓ 全绿
build (macos-15 arm64, needs: test)
  ├─ toolchain.py prepare → verify（缓存命中仍校验）
  ├─ build.sh：verify → make clean → make package
  ├─ verify_deb.py（失败即中断）
  ├─ toolchain.py receipt
  └─ 上传 artifact/证据 + 创建 Release（PR 不发布）
```

构建锁要求 Xcode `16.4` / `16F6`、clang build `1700.0.13.5`、Python `3.13.14`。
Actions 使用完整 commit SHA，缓存 key 包含完整锁文件 SHA-256、runner 架构和 scheme。
打包工具由 `locked_packaging.py` 校验十五个 bottle SHA 与固定 core formula 的 source/embedded 哈希；
从锁定 formula fetch 后比对 Homebrew 选中的 bottle，再以 `--ignore-dependencies --force-bottle` 安装，禁用滚动 API/自动更新。
实际 `ImageVersion` 只记录，不保证宿主镜像绝对固定；Homebrew/Ruby/系统 gzip 等为 `rolling-recorded`。
模板 1.3.0 的 RootHide 示例已通过工具安装、编译和验包验证。这个结果不自动适用于本项目；本项目应保留自己的准确源码 SHA、run/attempt、回执和验包记录。Swift 混编、其他 scheme 编译及真机运行按项目分别验证。

## 常见失败

| 现象 | 处理 |
|---|---|
| 缺文件 | 检查模板是否漏生成，包括工程根锁和两个工具链脚本 |
| 模板 token 残留 | 检查 `create.py` 的 `values` 键 |
| 开关缺 `sfIcon` | 补合法 SF Symbol 名 |
| 缺 arm64e | 检查 `ARCHS` 与工具链 |
| Xcode/平台或 PATH 校验失败 | 核对工程锁、实际 Xcode 版本/build、DEVELOPER_DIR 和工具解析路径；不退回浮动版本 |
| bottle/formula/SDK hash 不匹配 | 检查固定来源与缓存，停止构建；不能删除校验放行 |
| Git 用例 skip | 安装本地 Git 后重跑；skip 不计为通过 |
