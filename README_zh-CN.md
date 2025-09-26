# Sanger Blast Pipeline

**一个为Sanger测序数据设计的本地化、高通量BLAST注释流程。**

[English](./readme.md) | 中文

## 项目背景

在微生物分离与鉴定工作中，通过27F/1492R通用引物对细菌16S rRNA进行PCR扩增和Sanger测序，是一种经济、高效且广泛应用的物种鉴定方法。

然而，当测序样本数量庞大时，依赖NCBI官网或网页工具进行序列比对（BLAST）会因**网络限制**和**性能瓶颈**而变得效率低下。虽然本地化BLAST是理想的解决方案，但其环境配置和命令行操作对新手存在一定的技术门槛。

**本项目致力于消除这一障碍**，提供一个自动化、对新手友好的流程，让研究人员能够轻松地在本地计算机上批量完成Sanger测序序列的BLAST注释。

## 主要特性

  * **自动化**：自动下载和更新NCBI 16S rRNA数据库。
  * **高通量**：利用GNU Parallel并发处理大量测序文件，充分利用多核CPU性能。
  * **易于配置**：仅需修改一个配置文件即可指定工具和数据库路径。
  * **灵活易用**：支持自定义输入/输出目录、线程数、文件扩展名等常用参数。
  * **跨平台**：可在所有支持Bash环境的系统（Linux, macOS, WSL on Windows）上运行。

## 快速开始

### 1\. 克隆项目

选择以下任一方式将项目克隆到您的本地计算机：

```bash
# 方式一：从 GitHub 克隆
git clone https://github.com/CTR42/sanger_blast.git

# 方式二：国内用户可从 Gitee 克隆，速度更快
git clone https://gitee.com/CTR42/sanger_blast.git

# 进入项目目录
cd sanger_blast
```

### 2\. 安装依赖软件

本流程依赖于 `NCBI BLAST+` 和 `GNU Parallel`。

  * **NCBI BLAST+**: 用于执行本地序列比对。
      * [官方下载与安装指南](https://www.ncbi.nlm.nih.gov/books/NBK279671/)
  * **GNU Parallel**: 用于并行处理任务，加速流程。
      * [官方网站](https://www.gnu.org/software/parallel/)
      * 在基于Debian/Ubuntu的系统中：`sudo apt-get update && sudo apt-get install parallel`
      * 在macOS上使用Homebrew：`brew install parallel`

### 3\. 初始化配置

初次使用时，需要进行简单的配置。

**a. 赋予脚本执行权限**

```bash
# 为项目目录下所有.sh脚本添加可执行权限
find . -type f -name "*.sh" -exec chmod +x {} +
```

**b. 创建并修改配置文件**

我们提供了一个配置模板，请先复制一份再进行修改，以避免影响版本更新。

```bash
# 复制配置文件模板
cp sanger_blast.config.example sanger_blast.config
```

然后，使用您喜欢的文本编辑器（如 `vim` 或 `nano`）打开 `sanger_blast.config` 文件。

```bash
# 使用 vim 编辑 (推荐)
vim sanger_blast.config

# 或者使用 nano 编辑 (对新手更友好)
# nano sanger_blast.config
```

您需要修改文件中的两个路径变量：

  * `BLAST_PLUS_DIR`：指向您安装的 `NCBI BLAST+` 的 `bin` 目录 (例如: `/home/user/miniconda3/bin`)。
  * `NCBI_16S_DB_DIR`：指定一个用于存放BLAST数据库的目录 (例如: `/path/to/your/blast_db`)。

*Vim 简单操作提示: 按 `i` 进入编辑模式，修改完成后按 `Esc` 退出编辑模式，然后输入 `:wq` 并回车以保存并退出。*

## 使用方法

配置完成后，即可通过 `sanger_blast_pipeline.sh` 脚本来运行注释流程。

### 参数说明

```bash
sanger_blast_pipeline.sh -i <input_folder> -d <blast_db> -o <output_folder> -m <sequence_type> -n <threads> -x <file_extension> [-h]
```
| 参数 | 说明 |
| :--- | :--- |
| **`-i <文件夹路径>`** | **(必需)** 输入文件夹，包含您的Sanger测序文件。 |
| `-o <文件夹路径>` | 输出目录。(默认: `./blast_out`) |
| `-d <数据库路径>` | 指定本地BLAST数据库的路径。(默认: 使用配置文件中最新版) |
| `-m <序列类型>` | 序列类型: `single-end` 或 `contig`。(默认: `single-end`) |
| `-n <整数>` | 并行的任务数量/线程数。(默认: `8`) |
| `-x <扩展名>` | 测序文件的扩展名，不含"."。(默认: `seq`) |
| `-u <布尔值>` | 是否更新数据库: `true` 或 `false`。(默认: `false`) |
| `-h` | 显示此帮助信息。 |

### 使用示例

**示例1：基本使用**

假设您的测序文件（以 `.fasta` 结尾）存放在 `data/raw_reads` 目录下，您想使用16个线程进行比对，并将结果输出到 `output/blast_results` 文件夹。

```bash
bash sanger_blast_pipeline.sh -i data/raw_reads -o output/blast_results -n 16 -x fasta
```

**示例2：首次运行或更新数据库**

如果您是第一次使用，或者希望在运行前自动检查并更新NCBI 16S数据库，请将 `-u` 设为`true` 。

```bash
bash sanger_blast_pipeline.sh -i data/raw_reads -u true
```

*流程会自动处理数据库的下载、解压和命名，您无需手动干预。*

## 输出

流程结束后，您将在指定的输出目录（默认为 `blast_out`）中找到与输入文件同名的 `.txt` 结果文件。每个结果文件包含了对应序列在NCBI 16S数据库中最佳匹配的物种信息。以及一个汇总文件`summary.txt`。