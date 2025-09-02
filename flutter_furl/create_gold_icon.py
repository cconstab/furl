#!/usr/bin/env python3
"""
Create a FURL app icon using the gold padlock emoji style from the app
"""

try:
    from PIL import Image, ImageDraw, ImageFont
    import os
    
    # Create a 1024x1024 image
    size = 1024
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    # Create a deep blue/navy circular background like the app header
    center = size // 2
    radius = center - 50
    
    # Deep blue gradient background (matching app theme)
    draw.ellipse([center-radius, center-radius, center+radius, center+radius], 
                fill=(42, 69, 148, 255))  # Deep blue #2A4594
    
    # Add a subtle border
    draw.ellipse([center-radius, center-radius, center+radius, center+radius], 
                outline=(255, 255, 255, 40), width=8)
    
    # Draw a LARGE gold padlock in the emoji style
    padlock_size = 380  # Much larger for visibility
    padlock_x = center - padlock_size // 2
    padlock_y = center - padlock_size // 2 + 20
    
    # Gold colors (matching the emoji)
    gold_main = (255, 215, 0, 255)      # Gold #FFD700
    gold_dark = (218, 165, 32, 255)     # Dark gold #DAA520
    gold_light = (255, 255, 224, 255)   # Light gold #FFFFC0
    
    # Padlock body (main rectangle) - gold with gradient effect
    body_width = padlock_size
    body_height = padlock_size - 100
    body_top = padlock_y + 100
    
    # Create gradient effect by drawing multiple rectangles
    for i in range(body_height):
        blend_factor = i / body_height
        r = int(gold_main[0] * (1 - blend_factor) + gold_dark[0] * blend_factor)
        g = int(gold_main[1] * (1 - blend_factor) + gold_dark[1] * blend_factor)
        b = int(gold_main[2] * (1 - blend_factor) + gold_dark[2] * blend_factor)
        
        draw.rectangle([padlock_x, body_top + i, 
                       padlock_x + body_width, body_top + i + 1], 
                      fill=(r, g, b, 255))
    
    # Round the corners by drawing over with background color
    corner_size = 25
    # Top corners
    draw.ellipse([padlock_x - corner_size, body_top - corner_size, 
                 padlock_x + corner_size, body_top + corner_size], 
                fill=(42, 69, 148, 255))
    draw.ellipse([padlock_x + body_width - corner_size, body_top - corner_size, 
                 padlock_x + body_width + corner_size, body_top + corner_size], 
                fill=(42, 69, 148, 255))
    # Bottom corners
    draw.ellipse([padlock_x - corner_size, body_top + body_height - corner_size, 
                 padlock_x + corner_size, body_top + body_height + corner_size], 
                fill=(42, 69, 148, 255))
    draw.ellipse([padlock_x + body_width - corner_size, body_top + body_height - corner_size, 
                 padlock_x + body_width + corner_size, body_top + body_height + corner_size], 
                fill=(42, 69, 148, 255))
    
    # Padlock shackle (top curved part) - gold with thickness
    shackle_width = 200
    shackle_height = 140
    shackle_x = padlock_x + (body_width - shackle_width) // 2
    shackle_y = padlock_y
    
    # Draw thick gold shackle with multiple passes for thickness
    shackle_thickness = 35
    for thickness in range(shackle_thickness):
        draw.arc([shackle_x - thickness//2, shackle_y - thickness//2, 
                 shackle_x + shackle_width + thickness//2, shackle_y + shackle_height + thickness//2], 
                start=180, end=360, fill=gold_main, width=4)
    
    # Create hollow center of shackle (matching background)
    hollow_margin = 60
    for thickness in range(40):
        draw.arc([shackle_x + hollow_margin - thickness//2, shackle_y + hollow_margin - thickness//2, 
                 shackle_x + shackle_width - hollow_margin + thickness//2, 
                 shackle_y + shackle_height - hollow_margin + thickness//2], 
                start=180, end=360, fill=(42, 69, 148, 255), width=4)
    
    # Large keyhole - dark hole in the body
    keyhole_size = 70
    keyhole_x = center - keyhole_size // 2
    keyhole_y = body_top + 100
    
    # Keyhole circle
    draw.ellipse([keyhole_x, keyhole_y, keyhole_x + keyhole_size, keyhole_y + keyhole_size], 
                fill=(0, 0, 0, 180))
    
    # Keyhole slot
    slot_width = 30
    slot_height = 80
    slot_x = center - slot_width // 2
    slot_y = keyhole_y + keyhole_size - 15
    draw.rectangle([slot_x, slot_y, slot_x + slot_width, slot_y + slot_height], 
                  fill=(0, 0, 0, 180))
    
    # Add highlight on the padlock body for 3D effect
    highlight_height = body_height // 3
    for i in range(highlight_height):
        alpha = int(80 * (1 - i / highlight_height))
        draw.rectangle([padlock_x + 20, body_top + 20 + i, 
                       padlock_x + body_width - 20, body_top + 21 + i], 
                      fill=(255, 255, 255, alpha))
    
    # Add "FURL" text at bottom in white
    try:
        # Try to load a system font
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 90)
    except:
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 90)
        except:
            font = ImageFont.load_default()
    
    text = "FURL"
    text_bbox = draw.textbbox((0, 0), text, font=font)
    text_width = text_bbox[2] - text_bbox[0]
    text_x = center - text_width // 2
    text_y = center + radius - 140
    
    # Draw text with black outline for better visibility
    outline_size = 4
    for adj_x in range(-outline_size, outline_size + 1):
        for adj_y in range(-outline_size, outline_size + 1):
            if adj_x != 0 or adj_y != 0:
                draw.text((text_x + adj_x, text_y + adj_y), text, font=font, fill=(0, 0, 0, 255))
    
    # Draw main text in white
    draw.text((text_x, text_y), text, font=font, fill=(255, 255, 255, 255))
    
    # Save the image
    output_path = "assets/icons/app_icon.png"
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    image.save(output_path, "PNG")
    
    print(f"✅ Gold padlock FURL icon created: {output_path}")
    print(f"📐 Size: {size}x{size} pixels")
    print(f"🎨 Features: Deep blue background, gold padlock (emoji style), white FURL text")
    print(f"🔐 Style: Matches the app's header padlock emoji")
    
except ImportError:
    print("❌ PIL (Pillow) not available")
except Exception as e:
    print(f"❌ Error: {e}")
