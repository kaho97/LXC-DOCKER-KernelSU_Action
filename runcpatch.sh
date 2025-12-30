#!/bin/bash

# runcpatch.sh - 为Android内核添加runc支持的补丁脚本
# 该脚本会修改cgroup.c文件以添加对runc的支持

# 检查是否提供了文件路径参数
if [ -z "$1" ]; then
  echo "用法: $0 <cgroup.c文件路径>"
  exit 1
fi

CGROUP_FILE="$1"

# 检查文件是否存在
if [ ! -f "$CGROUP_FILE" ]; then
  echo "错误: 文件 $CGROUP_FILE 不存在"
  exit 1
fi

echo "正在为 $CGROUP_FILE 添加runc支持补丁..."

# 备份原文件
cp "$CGROUP_FILE" "${CGROUP_FILE}.bak"

# 添加runc支持所需的内核补丁
# 这些补丁通常包括添加对特定cgroup功能的支持

# 在文件开头添加必要的头文件包含（如果尚未包含）
if ! grep -q "#include.*linux/user_namespace.h" "$CGROUP_FILE"; then
  sed -i '/^#include.*linux\/cgroup.h/a #include <linux/user_namespace.h>' "$CGROUP_FILE"
fi

# 查找并修改cgroup相关函数
# 添加对cgroup命名空间的支持
if grep -q "struct cgroup_namespace" "$CGROUP_FILE"; then
  echo "检测到cgroup命名空间支持，跳过相关修改"
else
  # 在适当位置添加cgroup命名空间支持
  echo "正在添加cgroup命名空间支持..."
  
  # 查找cgroup结构体定义并添加命名空间支持
  if grep -q "struct cgroup" "$CGROUP_FILE" && ! grep -q "struct cgroup_namespace" "$CGROUP_FILE"; then
    # 在struct cgroup之后添加struct cgroup_namespace
    sed -i '/struct cgroup {/a \
	struct cgroup_namespace *ns;' "$CGROUP_FILE"
  fi
fi

# 添加必要的函数实现
# 检查是否已存在cgroup命名空间相关函数
if ! grep -q "cgroup_namespace_create" "$CGROUP_FILE"; then
  echo "正在添加cgroup命名空间创建函数..."
  
  # 在文件末尾添加必要的函数实现
  cat << 'EOF' >> "$CGROUP_FILE"

/*
 * RUNC support patches
 */
#ifdef CONFIG_USER_NS
static struct cgroup_namespace *cgroup_namespace_create(struct cgroup *cgroup)
{
	struct cgroup_namespace *ns;
	
	ns = kmalloc(sizeof(struct cgroup_namespace), GFP_KERNEL);
	if (!ns)
		return ERR_PTR(-ENOMEM);
		
	ns->root = cgroup->root;
	atomic_set(&ns->count, 1);
	
	return ns;
}
#endif /* CONFIG_USER_NS */

static void cgroup_namespace_free(struct cgroup_namespace *ns)
{
	if (!ns)
		return;
		
	if (atomic_dec_and_test(&ns->count)) {
		kfree(ns);
	}
}

EOF
fi

echo "runc支持补丁已成功应用到 $CGROUP_FILE"
echo "备份文件已保存为 ${CGROUP_FILE}.bak"