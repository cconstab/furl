#!/usr/bin/env python3
"""
Create app icon using the exact 🔐 emoji style from the app
"""

try:
    from PIL import Image, ImageDraw, ImageFont
    import os
    
    # Create a 1024x1024 image
    size = 1024
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    # Create the app's gradient background (purple theme matching the app)
    center = size // 2
    radius = center - 50
    
    # Create gradient from indigo to violet (matching app theme)
    for i in range(radius):
        factor = i / radius
        # From #4f46e5 (indigo) to #7c3aed (violet)
        r = int(79 * (1 - factor) + 124 * factor)
        g = int(70 * (1 - factor) + 58 * factor)
        b = int(229 * (1 - factor) + 237 * factor)
        
        draw.ellipse([center - radius + i, center - radius + i, 
                     center + radius - i, center + radius - i], 
                    fill=(r, g, b, 255))
    
    # 🔐 emoji recreation - golden padlock with key
    padlock_size = 320
    padlock_x = center - padlock_size // 2
    padlock_y = center - padlock_size // 2
    
    # Emoji-style gold colors
    gold_body = (255, 215, 0)      # Main gold #FFD700
    gold_dark = (218, 165, 32)     # Dark gold #DAA520
    gold_light = (255, 248, 220)   # Light gold #FFF8DC
    key_silver = (192, 192, 192)   # Silver for key #C0C0C0
    
    # Padlock body (rounded rectangle)
    body_width = int(padlock_size * 0.7)
    body_height = int(padlock_size * 0.6)
    body_x = padlock_x + (padlock_size - body_width) // 2
    body_y = padlock_y + int(padlock_size * 0.3)
    
    # Draw padlock body with gradient
    for y in range(body_height):
        blend = y / body_height
        r = int(gold_body[0] * (1 - blend) + gold_dark[0] * blend)
        g = int(gold_body[1] * (1 - blend) + gold_dark[1] * blend)
        b = int(gold_body[2] * (1 - blend) + gold_dark[2] * blend)
        
        draw.rectangle([body_x, body_y + y, body_x + body_width, body_y + y + 1], 
                      fill=(r, g, b, 255))
    
    # Round the corners
    corner_r = 20
    corners = [
        (body_x, body_y),  # top-left
        (body_x + body_width - corner_r*2, body_y),  # top-right
        (body_x, body_y + body_height - corner_r*2),  # bottom-left
        (body_x + body_width - corner_r*2, body_y + body_height - corner_r*2)  # bottom-right
    ]
    
    for corner_x, corner_y in corners:
        # Remove square corners
        draw.rectangle([corner_x, corner_y, corner_x + corner_r, corner_y + corner_r], 
                      fill=(r, g, b, 255))
    
    # Padlock shackle (top curved part)
    shackle_width = int(body_width * 0.6)
    shackle_height = int(padlock_size * 0.35)
    shackle_x = body_x + (body_width - shackle_width) // 2
    shackle_y = padlock_y
    
    # Draw shackle with thickness
    thickness = 25
    for t in range(thickness):
        draw.arc([shackle_x - t//2, shackle_y - t//2, 
                 shackle_x + shackle_width + t//2, shackle_y + shackle_height + t//2], 
                start=180, end=360, fill=gold_body, width=3)
    
    # Hollow center of shackle
    hollow_margin = 35
    for t in range(20):
        draw.arc([shackle_x + hollow_margin - t//2, shackle_y + hollow_margin - t//2, 
                 shackle_x + shackle_width - hollow_margin + t//2, 
                 shackle_y + shackle_height - hollow_margin + t//2], 
                start=180, end=360, fill=(r, g, b, 255), width=3)
    
    # Key (the distinctive part of 🔐)
    key_x = body_x + body_width + 20
    key_y = body_y + body_height // 2
    key_length = 80
    key_width = 15
    
    # Key shaft
    draw.rectangle([key_x, key_y - key_width//2, 
                   key_x + key_length, key_y + key_width//2], 
                  fill=key_silver)
    
    # Key head (circular)
    key_head_r = 25
    draw.ellipse([key_x - key_head_r, key_y - key_head_r, 
                 key_x + key_head_r, key_y + key_head_r], 
                fill=key_silver)
    
    # Key head hole
    hole_r = 8
    draw.ellipse([key_x - hole_r, key_y - hole_r, 
                 key_x + hole_r, key_y + hole_r], 
                fill=(r, g, b, 255))
    
    # Key teeth
    tooth_size = 10
    draw.rectangle([key_x + key_length - tooth_size, key_y + key_width//2, 
                   key_x + key_length, key_y + key_width//2 + tooth_size], 
                  fill=key_silver)
    draw.rectangle([key_x + key_length - tooth_size*2, key_y + key_width//2, 
                   key_x + key_length - tooth_size, key_y + key_width//2 + tooth_size//2], 
                  fill=key_silver)
    
    # Keyhole in padlock body
    keyhole_r = 15
    keyhole_x = body_x + body_width // 2
    keyhole_y = body_y + body_height // 2
    
    # Keyhole circle
    draw.ellipse([keyhole_x - keyhole_r, keyhole_y - keyhole_r, 
                 keyhole_x + keyhole_r, keyhole_y + keyhole_r], 
                fill=(0, 0, 0, 200))
    
    # Keyhole slot
    slot_w = 8
    slot_h = 25
    draw.rectangle([keyhole_x - slot_w//2, keyhole_y, 
                   keyhole_x + slot_w//2, keyhole_y + slot_h], 
                  fill=(0, 0, 0, 200))
    
    # Add highlight for 3D effect
    highlight_w = body_width // 3
    highlight_h = body_height // 4
    for i in range(highlight_h):
        alpha = int(100 * (1 - i / highlight_h))
        draw.rectangle([body_x + 15, body_y + 15 + i, 
                       body_x + 15 + highlight_w, body_y + 16 + i], 
                      fill=(255, 255, 255, alpha))
    
    # Save the image
    output_path = "assets/icons/app_icon.png"
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    image.save(output_path, "PNG")
    
    print(f"✅ 🔐 emoji-style app icon created: {output_path}")
    print(f"📐 Size: {size}x{size} pixels")
    print(f"🎨 Features: Purple gradient background, gold padlock with silver key")
    print(f"🔐 Style: Exact match to app's 🔐 emoji")
    
except ImportError:
    print("❌ PIL (Pillow) not available")
except Exception as e:
    print(f"❌ Error: {e}")
