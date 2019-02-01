#!/bin/bash

npm install -g hexo

mkdir yingsf.com

hexo init yingsf.com

cd yingsf.com

npm install

# 插件: 插入本地图片
npm install https://github.com/CodeFalling/hexo-asset-image --save

# 插件: 本地搜索
npm install hexo-generator-search --save

mkdir themes/next

curl -s https://api.github.com/repos/iissnan/hexo-theme-next/releases/latest | grep tarball_url | cut -d '"' -f 4 | wget -i - -O- | tar -zx -C themes/next --strip-components=1

# 以下sed命令在macos下不好使, BSD的sed和GNU的sed有区别
# 1. 修改站点配置文件

cp _config.yml _config.yml.bak

sed -i 's/title: Hexo/title: YSF/g' _config.yml

sed -i 's/subtitle:/subtitle: 5391 - 2885 - 1496/g' _config.yml

sed -i 's/description:/description: 面向自己编程/g' _config.yml

sed -i 's/keywords:/keywords: Ying, Blog/g' _config.yml

sed -i 's/author: John Doe/author: Yingsf/g' _config.yml

sed -i 's/language:/language: zh-Hans/g' _config.yml

sed -i 's#url: http://yoursite.com#url: https://yingsf.com#g' _config.yml

sed -i 's/post_asset_folder: false/post_asset_folder: true/g' _config.yml

sed -i 's/theme: landscape/theme: next/g' _config.yml

# 开启本地搜索
echo -e '#Local Search\nsearch:\n  path: search.xml\n  field: post\n' >> _config.yml
sed -i '/local_search/{N;s/false/true/g}' themes/next/_config.yml

# 2. 初始化页面
hexo new page categories

hexo new page tags

sed -i '/date:/a\type: "categories"' source/categories/index.md

sed -i '/date:/a\type: "tags"' source/tags/index.md

sed -i 's/title: categories/title: 分类/g' source/categories/index.md

sed -i 's/title: tags/title: 标签/g' source/tags/index.md

sed -i 's/#tags: \/tags\/ || tags/tags: \/tags\/ || tags/g' themes/next/_config.yml

sed -i 's/#categories: \/categories\/ || th/categories: \/categories\/ || th/g' themes/next/_config.yml

# 3. 选择next的风格
sed -i 's/scheme: Muse/#scheme: Muse/g' themes/next/_config.yml
sed -i 's/#scheme: Gemini/scheme: Gemini/g' themes/next/_config.yml

# 4. 开启社交连接
sed -i 's/#social/social/g' themes/next/_config.yml
sed -i 's/#GitHub:/GitHub:/g' themes/next/_config.yml
sed -i 's/#E-Mail:/E-Mail:/g' themes/next/_config.yml
sed -i 's/https:\/\/github.com\/yourname/https:\/\/github.com\/yingsf/g' themes/next/_config.yml
sed -i 's/mailto:yourname@gmail.com/mailto:me@yingsf.com/g' themes/next/_config.yml

# 5. 修改post模板(开启资源文件夹选项已经在上面post_asset_folder参数中打开了)
sed -i '/tags/a\categories:' scaffolds/post.md
sed -i '/title/i\layout: post' scaffolds/post.md
echo -e '这部分算摘要,注意他和正文其实是一体的\n\n<!-- more -->\n\n这是正文,上接摘要\n' >> scaffolds/post.md

# 6. 设置代码高亮格式
sed -i 's/highlight_theme: normal/highlight_theme: night bright/g' themes/next/_config.yml

# 7. 设置头像
wget https://github.com/yingsf/myshs/raw/master/hexo-icon/header.png
mv header.png themes/next/source/images
sed -i 's/#avatar: \/images\/avatar.gif/avatar: \/images\/header.png/g' themes/next/_config.yml

# 8. 修改关键字
sed -i 's/keywords: "Hexo, NexT"/keywords: "Ying, Blog"/g' themes/next/_config.yml

# 9. 隐藏底部next驱动
sed -i 's/powered: true/powered: false/g' themes/next/_config.yml
sed -i '/Theme - NexT.scheme/{N;s/true/false/g}' themes/next/_config.yml
sed -i '/scheme info (vX.X.X)./{N;s/true/false/g}' themes/next/_config.yml

# 10. 修改浏览器标签栏图标
wget https://github.com/yingsf/myshs/raw/master/hexo-icon/favicon-16.png
wget https://github.com/yingsf/myshs/raw/master/hexo-icon/favicon-32.png
wget https://github.com/yingsf/myshs/raw/master/hexo-icon/logo.svg
mv favicon-16.png favicon-32.png logo.svg themes/next/source/images
sed -i 's/small: \/images\/favicon-16x16-next.png/small: \/images\/favicon-16.png/g' themes/next/_config.yml
sed -i 's/small: \/images\/favicon-32x32-next.png/small: \/images\/favicon-32.png/g' themes/next/_config.yml

# 11. 增加顶部加载条
sed -i 's/pace: false/pace: true/g' themes/next/_config.yml

# 12. 替换文章最下的标签图标
sed -i 's/rel="tag">#/rel="tag"><i class="fa fa-tag"><\/i>/g' themes/next/layout/_macro/post.swig