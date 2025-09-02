#!/usr/bin/env python3
"""
Create Android launcher icons in the required resolutions
"""

try:
    from PIL import Image
    import os
    
    # Load the main icon
    main_icon_path = "assets/icons/app_icon.png"
    if not os.path.exists(main_icon_path):
        print(f"❌ Main icon not found at {main_icon_path}")
        exit(1)
    
    main_icon = Image.open(main_icon_path)
    
    # Android icon sizes (drawable folders)
    android_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192
    }
    
    android_res_path = "android/app/src/main/res"
    
    for folder, size in android_sizes.items():
        folder_path = os.path.join(android_res_path, folder)
        os.makedirs(folder_path, exist_ok=True)
        
        # Resize and save
        resized_icon = main_icon.resize((size, size), Image.Resampling.LANCZOS)
        icon_path = os.path.join(folder_path, "launcher_icon.png")
        resized_icon.save(icon_path, "PNG")
        print(f"✅ Created {icon_path} ({size}x{size})")
    
    # Also create the main ic_launcher.png (this might be needed)
    for folder, size in android_sizes.items():
        folder_path = os.path.join(android_res_path, folder)
        resized_icon = main_icon.resize((size, size), Image.Resampling.LANCZOS)
        icon_path = os.path.join(folder_path, "ic_launcher.png")
        resized_icon.save(icon_path, "PNG")
        print(f"✅ Created {icon_path} ({size}x{size})")
        
    print(f"\n🎉 Android launcher icons created successfully!")
    print(f"📁 Icons created in: {android_res_path}")
    
except ImportError:
    print("❌ PIL (Pillow) not available")
except Exception as e:
    print(f"❌ Error: {e}")
