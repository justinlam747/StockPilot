import re

with open('app/assets/stylesheets/landing.css', 'r', encoding='utf-8') as f:
    content = f.read()

# Find NAV LINKS section
idx = content.find('.lp-nav__links')
# Go back to find the comment before it
comment_start = content.rfind('/*', 0, idx)
vision_styles = content[comment_start:]

new_landing = open('scripts/new-landing.css', 'r', encoding='utf-8').read()

with open('app/assets/stylesheets/landing.css', 'w', encoding='utf-8') as f:
    f.write(new_landing + '\n' + vision_styles)

print(f'Written: {len(new_landing)} landing + {len(vision_styles)} vision chars')
