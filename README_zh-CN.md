# Sanger Blast Pipeline

**一款专为一代测序（Sanger测序）数据处理设计的本地化、高吞吐 BLAST 物种注释流程。**

[English](https://www.google.com/search?q=./README.md) | 中文

## 背景系统

在微生物的分离与鉴定工作中，利用 27F/1492R 等通用引物对细菌 16S rRNA 基因进行 PCR 扩增并进行 Sanger 测序，是一种经济、高效且应用广泛的物种鉴定方法。

然而，当面对大量的测序样本时，若依赖 NCBI 官网或其他在线网页工具进行序列比对（BLAST），往往会因为**网络带宽限制**和**平台性能瓶颈**导致效率极低。虽然搭建本地 BLAST 是理想的解决方案，但其繁琐的环境配置和纯命令行操作，对许多生信初学者来说具有较高的技术门槛。

**本项目的目标正是为了消除这一门槛。** 我们提供了一个自动化、对初学者极其友好的流水线流程，让研究人员能够轻松地在本地计算机上对 Sanger 测序数据进行批量的 BLAST 物种注释。

---

## 核心特性

* **端到端自动化：** 自动完成序列单行化预处理、动态质控剪切、高并发 BLAST 比对以及最优匹配结果（Top Hit）的自动化汇总。
* **智能数据库管理：** 完美支持**在线自动更新**（基于 wget/curl）与**离线手动更新**双模式。系统会自动解析版本日期、验证 MD5 校验码，并对旧版本数据库进行安全归档。
* **动态序列修剪（Trimming）：** 内置支持指定左端截去的碱基数以及后续保留的准确序列长度，确保用于比对的均是高质测序区域。
* **高吞吐量并发加速：** 引入 GNU Parallel 框架，支持多核 CPU 并发处理海量序列文件，最大化释放服务器算力。
* **完善的日志与可追溯性：** 运行成功后，系统会自动将详细的运行日志与本次分析所用数据库的凭证（`db_version_info.txt`）整合归档至输出目录。
* **严格的配置校验：** 采用集中式配置文件，脚本启动时会对依赖软件的绝对路径进行严格的前置检查，杜绝运行中途报错。

---

## 快速开始

### 1. 克隆本项目

通过以下任意一种方式将项目克隆到本地服务器：

```bash
# 方法一：从 GitHub 克隆
git clone https://github.com/CTR42/sanger_blast.git

# 方法二：国内用户推荐使用 Gitee，速度更快
git clone https://gitee.com/CTR42/sanger_blast.git

# 进入项目目录
cd sanger_blast

```

### 2. 安装依赖软件

本流程的核心运行依赖于 **NCBI BLAST+** 和 **GNU Parallel**。请确保系统已安装它们：

* **NCBI BLAST+**: [官方下载与安装指南](https://www.ncbi.nlm.nih.gov/books/NBK279671/)
* **GNU Parallel**: Debian/Ubuntu 系统：`sudo apt-get install parallel` | macOS 系统：`brew install parallel`

### 3. 初始化配置

首次使用前，需要完成一次性的前置设置。

**a. 赋予脚本执行权限**

```bash
# 为项目目录下的所有 .sh 脚本批量添加可执行权限
find . -type f -name "*.sh" -exec chmod +x {} +

```

**b. 创建并修改配置文件**
从模版复制一份配置文件，以避免后续更新时发生冲突：

```bash
cp sanger_blast.config.example sanger_blast.config

```

使用文本编辑器（如 `vim` 或 `nano`）打开 `sanger_blast.config`，配置以下核心软件及目录的绝对路径：

* `NCBI_16S_DB_DIR`：你希望存放 NCBI 16S 本地数据库的父目录路径。
* `BLASTN_PATH`：你系统里 `blastn` 可执行程序的绝对路径（如 `/usr/local/bin/blastn`）。
* `PARALLEL_PATH`：你系统里 `parallel` 可执行程序的绝对路径（如 `/usr/bin/parallel`）。

---

## 使用说明

整个流程通过主脚本 `sanger_blast_pipeline.sh` 进行控制，主要分为两大功能：**数据库更新 (`update`)** 和 **批量物种注释 (`-i`)**。

### 模式一：数据库自动部署与更新 (`update`)

在进行任何序列比对之前，必须先部署本地的 NCBI 16S 数据库。

**联网自动更新：**
如果你的服务器网络畅通，直接运行以下命令即可：

```bash
bash sanger_blast_pipeline.sh update

```

*脚本会自动从 NCBI 下载最新的 16S 数据库、校验 MD5、完成解压部署，并将旧库安全移至 archived 目录。*

**完全离线更新：**
若服务器处于内网或断网环境，你可以在个人电脑上提前下载好 `.tar.gz` 压缩包和对应的 `.md5` 文件，上传至服务器后运行：

```bash
bash sanger_blast_pipeline.sh update -f /路径/16S_ribosomal_RNA.tar.gz -m /路径/16S_ribosomal_RNA.tar.gz.md5

```

*脚本将直接启动本地校验和解压部署，期间完全不触发任何网络请求。*

### 模式二：批量物种注释主流程

对准备好的测序数据目录执行批量鉴定。

**命令行语法：**

```bash
bash sanger_blast_pipeline.sh -i <输入文件夹> [可选项]

```

**参数详解：**

| 参数 | 描述 | 默认值 |
| --- | --- | --- |
| **`-i <路径>`** | **(必填)** 存放原始 Sanger 测序序列文件的文件夹路径。 | 无 |
| `-o <路径>` | 结果输出及日志存放的文件夹路径。 | `./blast_out` |
| `-t <字符串>` | 序列类型：`single-end` (单端，触发质控修剪) 或 `contig` (拼接序列)。 | `single-end` |
| `-x <字符串>` | 测序文件的后缀名（不要带“.”）。 | `seq` |
| `-n <整数>` | 并发运行的任务/线程数。 | `8` |
| `-l <整数>` | 序列**左端**（5'端）截去的碱基数。 | `30` |
| `-k <整数>` | 左端截去后，序列期望**保留**的总长度。 | `700` |
| `-d <路径>` | 临时指定的本地数据库路径（一般不填，默认读取配置）。 | 配置中的 `latest` |
| `-h` | 显示帮助信息。 | N/A |

**运行示例：**

*示例 1：常规物种注释（指定16线程并处理 `.fasta` 后缀文件）*

```bash
bash sanger_blast_pipeline.sh -i data/raw_reads -o output/results -n 16 -x fasta

```

*示例 2：自定义质控参数比对*
切除左端 50 bp 的低质量引物区，并保留其后完整的 800 bp 核心区域进行比对：

```bash
bash sanger_blast_pipeline.sh -i data/raw_reads -o output/results -l 50 -k 800

```

---

## 输出结果结构

流程运行成功结束后，你指定的输出文件夹（如 `blast_out/`）下会生成以下文件：

1. **`summary.txt`**：最终的自动化汇总报告。直观展示了每个样本序列比对到的最佳匹配物种（Top Hit）、Accession 号、Max Score、E值、相似度（Identity）等。
2. **独立的详细比对文件 (`*_blast_out.txt`)**：每个样品对应的详细 BLAST 前 5 位比对丰度文件，供深度排查使用。
3. **`sanger_blast_年月日_时分秒.log`**：完整的运行日志。系统运行结束后会自动将其移动至该输出目录下，方便实验记录归档。
4. **`db_version_info.txt` 内嵌信息**：该日志的最底部已自动附带了本次比对所调用的 NCBI 16S 数据库的官方发布日期、更新时间及部署路径，确保实验具有绝对的可重复性。