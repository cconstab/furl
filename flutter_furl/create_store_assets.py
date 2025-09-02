#!/usr/bin/env python3
"""
Create Google Play Store feature graphic (1024x500)
"""

try:
    from PIL import Image, ImageDraw, ImageFont
    import os
    
    # Create feature graphic (1024x500)
    width, height = 1024, 500
    image = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    # Create gradient background
    for y in range(height):
        # Purple to blue gradient
        ratio = y / height
        r = int(79 + (116 - 79) * ratio)  # 4f46e5 to 7c3aed
        g = int(70 + (58 - 70) * ratio)
        b = int(229 + (237 - 229) * ratio)
        
        draw.rectangle([0, y, width, y+1], fill=(r, g, b, 255))
    
    # Add app icon on the left side
    icon_size = 300
    icon_x = 50
    icon_y = (height - icon_size) // 2
    
    # Load and resize the app icon if it exists
    icon_path = "assets/icons/app_icon.png"
    if os.path.exists(icon_path):
        app_icon = Image.open(icon_path)
        app_icon = app_icon.resize((icon_size, icon_size), Image.Resampling.LANCZOS)
        
        # Create a circular mask for the icon
        mask = Image.new('L', (icon_size, icon_size), 0)
        mask_draw = ImageDraw.Draw(mask)
        mask_draw.ellipse([20, 20, icon_size-20, icon_size-20], fill=255)
        
        # Apply mask and paste
        app_icon.putalpha(mask)
        image.paste(app_icon, (icon_x, icon_y), app_icon)
    else:
        # Draw a placeholder circle if icon doesn't exist
        draw.ellipse([icon_x, icon_y, icon_x + icon_size, icon_y + icon_size], 
                    fill=(255, 255, 255, 200), outline=(255, 255, 255, 255), width=4)
    
    # Add text on the right side
    text_x = icon_x + icon_size + 80
    text_y_center = height // 2
    
    # Try to use a nice font, fall back to default
    try:
        title_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 72)
        subtitle_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 36)
    except:
        try:
            title_font = ImageFont.truetype("arial.ttf", 72)
            subtitle_font = ImageFont.truetype("arial.ttf", 36)
        except:
            title_font = ImageFont.load_default()
            subtitle_font = ImageFont.load_default()
    
    # Draw title
    title_text = "FURL"
    title_bbox = draw.textbbox((0, 0), title_text, font=title_font)
    title_width = title_bbox[2] - title_bbox[0]
    title_height = title_bbox[3] - title_bbox[1]
    
    draw.text((text_x, text_y_center - 60), title_text, 
             fill=(255, 255, 255, 255), font=title_font)
    
    # Draw subtitle
    subtitle_text = "Secure File Sharing"
    draw.text((text_x, text_y_center + 20), subtitle_text, 
             fill=(255, 255, 255, 200), font=subtitle_font)
    
    # Add feature bullets
    features = [
        "🔒 End-to-end encryption",
        "🔗 Secure temporary URLs", 
        "� PIN-protected access"
    ]
    
    feature_y = text_y_center + 80
    for feature in features:
        draw.text((text_x, feature_y), feature, 
                 fill=(255, 255, 255, 180), font=subtitle_font)
        feature_y += 40
    
    # Save the feature graphic
    output_path = "assets/store/feature_graphic.png"
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    image.save(output_path, "PNG")
    
    print(f"✅ Feature graphic created: {output_path}")
    print(f"📐 Size: {width}x{height} pixels")
    
    # Also create a high-res app icon for store (512x512)
    if os.path.exists(icon_path):
        app_icon = Image.open(icon_path)
        store_icon = app_icon.resize((512, 512), Image.Resampling.LANCZOS)
        store_icon_path = "assets/store/app_icon_512.png"
        store_icon.save(store_icon_path, "PNG")
        print(f"✅ Store icon created: {store_icon_path}")
        print(f"📐 Size: 512x512 pixels")
    
except ImportError:
    print("❌ PIL (Pillow) not available")
    print("📝 Please create store graphics manually:")
    print("  • Feature graphic: 1024x500 px")
    print("  • High-res icon: 512x512 px")
except Exception as e:
    print(f"❌ Error: {e}")
