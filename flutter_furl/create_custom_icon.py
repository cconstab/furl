#!/usr/bin/env python3
"""
Create a more prominent custom FURL app icon
"""

try:
    from PIL import Image, ImageDraw, ImageFont
    import os
    
    # Create a 1024x1024 image
    size = 1024
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    # Create a purple gradient background circle
    center = size // 2
    radius = 480
    
    # Draw gradient circle
    for i in range(radius):
        # Create gradient from deep purple to lighter purple
        ratio = i / radius
        r = int(101 + (139 - 101) * ratio)  # 6563e5 to 8b5cf6
        g = int(99 + (92 - 99) * ratio)
        b = int(229 + (246 - 229) * ratio)
        alpha = 255
        
        draw.ellipse([center-i, center-i, center+i, center+i], 
                    fill=(r, g, b, alpha))
    
    # Add a white border
    draw.ellipse([center-radius, center-radius, center+radius, center+radius], 
                outline=(255, 255, 255, 255), width=8)
    
    # Draw FURL text in large, bold letters
    try:
        # Try to use a system font
        font_size = 180
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except:
        try:
            font = ImageFont.truetype("arial.ttf", font_size)
        except:
            font = ImageFont.load_default()
    
    # Draw "FURL" text
    text = "FURL"
    
    # Get text dimensions
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    # Center the text
    text_x = (size - text_width) // 2
    text_y = (size - text_height) // 2 - 40
    
    # Draw text with shadow effect
    shadow_offset = 4
    draw.text((text_x + shadow_offset, text_y + shadow_offset), text, 
             fill=(0, 0, 0, 100), font=font)
    draw.text((text_x, text_y), text, fill=(255, 255, 255, 255), font=font)
    
    # Add a padlock symbol below
    padlock_y = text_y + text_height + 20
    
    # Draw a large padlock
    padlock_size = 120
    padlock_x = center - padlock_size // 2
    
    # Padlock body
    body_height = padlock_size
    body_width = padlock_size
    draw.rounded_rectangle([padlock_x, padlock_y + 30, 
                           padlock_x + body_width, padlock_y + body_height], 
                          radius=20, fill=(255, 255, 255, 255))
    
    # Padlock shackle
    shackle_width = 60
    shackle_height = 40
    shackle_x = center - shackle_width // 2
    shackle_y = padlock_y
    
    # Outer shackle
    draw.arc([shackle_x - 8, shackle_y, shackle_x + shackle_width + 8, shackle_y + shackle_height + 20], 
             start=180, end=360, fill=(255, 255, 255, 255), width=16)
    
    # Inner shackle (hollow effect)
    draw.arc([shackle_x + 8, shackle_y + 8, shackle_x + shackle_width - 8, shackle_y + shackle_height + 12], 
             start=180, end=360, fill=(101, 99, 229, 255), width=16)
    
    # Keyhole in padlock body
    keyhole_size = 20
    keyhole_x = center - keyhole_size // 2
    keyhole_y = padlock_y + 50
    draw.ellipse([keyhole_x, keyhole_y, keyhole_x + keyhole_size, keyhole_y + keyhole_size], 
                fill=(101, 99, 229, 255))
    
    # Keyhole slot
    slot_width = 8
    slot_height = 25
    slot_x = center - slot_width // 2
    slot_y = keyhole_y + keyhole_size - 5
    draw.rectangle([slot_x, slot_y, slot_x + slot_width, slot_y + slot_height], 
                  fill=(101, 99, 229, 255))
    
    # Save the image
    output_path = "assets/icons/app_icon.png"
    image.save(output_path, "PNG")
    
    print(f"✅ Custom FURL app icon created: {output_path}")
    print(f"📐 Size: {size}x{size} pixels")
    print(f"🎨 Features: FURL text + padlock symbol on purple gradient")
    
except ImportError:
    print("❌ PIL (Pillow) not available")
except Exception as e:
    print(f"❌ Error: {e}")
