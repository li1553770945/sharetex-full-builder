#!/usr/bin/env python3
"""
获取 Docker Hub 上 latest 标签对应的真实版本号

用法:
    python3 get_latest_version.py <repository>
    
例如:
    python3 get_latest_version.py sharelatex/sharelatex
"""

import json
import sys
import urllib.request
from typing import Optional


def get_latest_version(repo: str) -> Optional[str]:
    """
    获取指定仓库的 latest 标签对应的真实版本号
    
    Args:
        repo: Docker Hub 仓库名称，格式为 "namespace/repo"
        
    Returns:
        版本号字符串，如果失败则返回 None
    """
    try:
        # 获取 latest 的 digest
        latest_url = f'https://hub.docker.com/v2/repositories/{repo}/tags/latest'
        with urllib.request.urlopen(latest_url) as f:
            latest_data = json.load(f)
            digest = latest_data.get('digest', '')
        
        if not digest:
            return None
        
        # 获取所有标签
        tags_url = f'https://hub.docker.com/v2/repositories/{repo}/tags/?page_size=100'
        with urllib.request.urlopen(tags_url) as f:
            tags_data = json.load(f)
        
        # 找到相同 digest 的版本号标签
        versions = []
        for tag in tags_data.get('results', []):
            tag_digest = tag.get('digest', '')
            tag_name = tag.get('name', '')
            if tag_digest == digest and tag_name != 'latest':
                versions.append(tag_name)
        
        if not versions:
            return None
        
        # 简单的版本排序（语义化版本号）
        def version_key(v: str) -> tuple:
            """将版本号转换为可排序的元组"""
            parts = v.replace('-', '.').split('.')
            return tuple(int(p) if p.isdigit() else 999999 for p in parts)
        
        versions.sort(key=version_key)
        return versions[-1]
        
    except Exception as e:
        # 静默失败，返回 None
        return None


def main():
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        sys.exit(1)
    
    repo = sys.argv[1]
    version = get_latest_version(repo)
    
    if version:
        print(version)
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == '__main__':
    main()
