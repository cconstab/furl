#!/usr/bin/env python3
"""
Create a very visible custom FURL app icon with larger elements
"""

try:
    from PIL import Image, ImageDraw, ImageFont
    import os
    
    # Create a 1024x1024 image
    size = 1024
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    # Create a solid circular background with vibrant purple
    center = size // 2
    radius = center - 50
    
    # Draw solid purple circle
    draw.ellipse([center-radius, center-radius, center+radius, center+radius], 
                fill=(103, 58, 183, 255))  # Purple #673AB7
    
    # Add a white border
    draw.ellipse([center-radius, center-radius, center+radius, center+radius], 
                outline=(255, 255, 255, 255), width=20)
    
    # Draw a LARGE padlock in the center
    padlock_size = 300  # Much larger
    padlock_x = center - padlock_size // 2
    padlock_y = center - padlock_size // 2 + 30
    
    # Padlock body (main rectangle) - white for visibility
    body_width = padlock_size
    body_height = padlock_size - 80
    body_top = padlock_y + 80
    
    draw.rounded_rectangle([padlock_x, body_top, 
                           padlock_x + body_width, body_top + body_height], 
                          radius=20, fill=(255, 255, 255, 255))
    
    # Padlock shackle (top curved part) - white outline
    shackle_width = 160
    shackle_height = 120
    shackle_x = padlock_x + (body_width - shackle_width) // 2
    shackle_y = padlock_y
    
    # Draw thick white shackle
    for thickness in range(25):
        draw.arc([shackle_x - thickness, shackle_y - thickness, 
                 shackle_x + shackle_width + thickness, shackle_y + shackle_height + thickness], 
                start=180, end=360, fill=(255, 255, 255, 255), width=3)
    
    # Create hollow center of shackle
    hollow_margin = 40
    draw.arc([shackle_x + hollow_margin, shackle_y + hollow_margin, 
             shackle_x + shackle_width - hollow_margin, shackle_y + shackle_height - hollow_margin], 
            start=180, end=360, fill=(103, 58, 183, 255), width=60)
    
    # Large keyhole - purple circle
    keyhole_size = 50
    keyhole_x = center - keyhole_size // 2
    keyhole_y = body_top + 80
    draw.ellipse([keyhole_x, keyhole_y, keyhole_x + keyhole_size, keyhole_y + keyhole_size], 
                fill=(103, 58, 183, 255))
    
    # Keyhole slot - purple rectangle
    slot_width = 20
    slot_height = 60
    slot_x = center - slot_width // 2
    slot_y = keyhole_y + keyhole_size - 10
    draw.rectangle([slot_x, slot_y, slot_x + slot_width, slot_y + slot_height], 
                  fill=(103, 58, 183, 255))
    
    # Add "FURL" text at bottom
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 80)
    except:
        font = ImageFont.load_default()
    
    text = "FURL"
    text_bbox = draw.textbbox((0, 0), text, font=font)
    text_width = text_bbox[2] - text_bbox[0]
    text_x = center - text_width // 2
    text_y = center + radius - 120
    
    # Draw text with outline
    for adj in range(-3, 4):
        for adj2 in range(-3, 4):
            draw.text((text_x + adj, text_y + adj2), text, font=font, fill=(255, 255, 255, 255))
    draw.text((text_x, text_y), text, font=font, fill=(103, 58, 183, 255))
    
    # Save the image
    output_path = "assets/icons/app_icon.png"
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    image.save(output_path, "PNG")
    
    print(f"✅ Large custom FURL icon created: {output_path}")
    print(f"📐 Size: {size}x{size} pixels")
    print(f"🎨 Features: Purple background, white padlock, FURL text")
    
except ImportError:
    print("❌ PIL (Pillow) not available")
except Exception as e:
    print(f"❌ Error: {e}")
