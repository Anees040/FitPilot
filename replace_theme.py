import os
import re

def process_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    replacements = {
        r'AppTheme\.bg': r'Theme.of(context).scaffoldBackgroundColor',
        r'AppTheme\.scaffoldBackground': r'Theme.of(context).scaffoldBackgroundColor',
        r'AppTheme\.surface': r'Theme.of(context).colorScheme.surface',
        r'AppTheme\.text': r'Theme.of(context).colorScheme.onSurface',
        r'AppTheme\.primaryText': r'Theme.of(context).colorScheme.onSurface',
        r'AppTheme\.secondaryText': r'Theme.of(context).textTheme.bodySmall!.color!',
        r'AppTheme\.hairline': r'Theme.of(context).dividerColor',
        r'AppTheme\.accent': r'Theme.of(context).colorScheme.primary',
        r'AppTheme\.error': r'Theme.of(context).colorScheme.error',
        r'AppTheme\.success': r'Theme.of(context).extension<AppColors>()!.success',
        r'AppTheme\.warning': r'Theme.of(context).extension<AppColors>()!.warning',
        
        r'AppTheme\.display': r'Theme.of(context).textTheme.displayLarge!',
        r'AppTheme\.title': r'Theme.of(context).textTheme.titleLarge!',
        r'AppTheme\.body': r'Theme.of(context).textTheme.bodyLarge!',
        r'AppTheme\.secondary': r'Theme.of(context).textTheme.bodyMedium!',
        r'AppTheme\.caption': r'Theme.of(context).textTheme.bodySmall!',
        
        r'AppTheme\.lightTheme\.textTheme': r'Theme.of(context).textTheme',
        
        r'Colors\.white54': r'Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)',
        r'Colors\.black54': r'Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)',
        r'Colors\.white\.withValues': r'Theme.of(context).colorScheme.onPrimary.withValues',
        r'Colors\.black\.withValues': r'Theme.of(context).colorScheme.onSurface.withValues',
        
        r'backgroundColor:\s*Colors\.white': r'backgroundColor: Theme.of(context).colorScheme.surface',
        r'backgroundColor:\s*Colors\.black': r'backgroundColor: Theme.of(context).colorScheme.onSurface',
        r'foregroundColor:\s*Colors\.white': r'foregroundColor: Theme.of(context).colorScheme.onPrimary',
        r'foregroundColor:\s*Colors\.black': r'foregroundColor: Theme.of(context).colorScheme.onSurface',
        r'color:\s*Colors\.white': r'color: Theme.of(context).colorScheme.onPrimary',
        r'color:\s*Colors\.black': r'color: Theme.of(context).colorScheme.onSurface',
        r'Colors\.transparent': r'const Color(0x00000000)',
    }
    
    new_content = content
    for pattern, repl in replacements.items():
        new_content = re.sub(pattern, repl, new_content)
        
    # Remove const before widgets that now use Theme.of(context)
    # E.g. const Icon(Icons.close, color: Theme.of(context)...)
    new_content = re.sub(r'const\s+([A-Z][A-Za-z0-9_]*\([^)]*Theme\.of)', r'\1', new_content)
    new_content = re.sub(r'const\s+(TextStyle\([^)]*Theme\.of)', r'\1', new_content)
    
    if new_content != content:
        # Check if AppColors needs to be imported
        if 'Theme.of(context).extension<AppColors>' in new_content and 'package:fitpilot/core/theme/app_theme.dart' not in new_content:
            new_content = "import 'package:fitpilot/core/theme/app_theme.dart';\n" + new_content
            
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new_content)

for root, _, files in os.walk('d:/fitpilot/lib'):
    for file in files:
        if file.endswith('.dart') and file != 'app_theme.dart':
            process_file(os.path.join(root, file))
