// SPDX-License-Identifier: GPL-2.0
#include <linux/fs.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <asm/setup.h>

#ifdef KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG
extern int susfs_spoof_cmdline_or_bootconfig(struct seq_file *m);
#endif

static char new_command_line[COMMAND_LINE_SIZE];

static int cmdline_proc_show(struct seq_file *m, void *v)
{
#ifdef CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG
	if (!susfs_spoof_cmdline_or_bootconfig(m)) {
		seq_putc(m, '\n');
		return 0;
	}
#endif
	seq_printf(m, "%s\n", new_command_line);
	seq_putc(m, '\n');
	return 0;
}

static int cmdline_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, cmdline_proc_show, NULL);
}

static const struct file_operations cmdline_proc_fops = {
	.open		= cmdline_proc_open,
	.read		= seq_read,
	.llseek		= seq_lseek,
	.release	= single_release,
};

static int __init proc_cmdline_init(void)
{
	char *offset_addr, *cmd = new_command_line;
	size_t search_len, replace_len;

	strcpy(cmd, saved_command_line);

	char *search = "skip_initramf";
	char *replace = "androidboot.force_normal_boot=1 ";
	search_len = strlen(search);
	replace_len = strlen(replace);

	offset_addr = strstr(cmd, search);
	if (offset_addr) {
		size_t tail_len;
		tail_len = strlen(offset_addr+search_len);

		memmove(offset_addr+replace_len,offset_addr+search_len,tail_len+1);
		memcpy(offset_addr, replace, replace_len);
	}

	proc_create("cmdline", 0, NULL, &cmdline_proc_fops);
	return 0;
}
fs_initcall(proc_cmdline_init);
