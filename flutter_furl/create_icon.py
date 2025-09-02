#!/usr/bin/env python3
"""
Simple script to create a FURL app icon using PIL
"""

try:
    from PIL import Image, ImageDraw, ImageFont
    import os
    
    # Create a 1024x1024 image with a gradient background
    size = 1024
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    # Create a circular gradient background
    center = size // 2
    for i in range(center):
        # Create gradient from purple to blue
        r = int(79 + (116 - 79) * i / center)  # 4f46e5 to 7c3aed
        g = int(70 + (58 - 70) * i / center)
        b = int(229 + (237 - 229) * i / center)
        alpha = 255
        
        draw.ellipse([center-i, center-i, center+i, center+i], 
                    fill=(r, g, b, alpha))
    
    # Draw a document icon in the center
    doc_width = 200
    doc_height = 260
    doc_x = center - doc_width // 2
    doc_y = center - doc_height // 2
    
    # Main document rectangle
    draw.rectangle([doc_x, doc_y, doc_x + doc_width, doc_y + doc_height], 
                  fill=(255, 255, 255, 255), outline=None)
    
    # Document corner fold
    fold_size = 40
    draw.polygon([
        (doc_x + doc_width - fold_size, doc_y),
        (doc_x + doc_width, doc_y + fold_size),
        (doc_x + doc_width - fold_size, doc_y + fold_size)
    ], fill=(199, 210, 254, 255))
    
    # Add padlock icon (security symbol)
    padlock_x = center - 30
    padlock_y = center + 40
    padlock_width = 60
    padlock_height = 70
    
    # Padlock body (main rectangle)
    body_top = padlock_y + 25
    draw.rounded_rectangle([padlock_x, body_top, 
                           padlock_x + padlock_width, body_top + padlock_height - 25], 
                          radius=8, fill=(79, 70, 229, 255))
    
    # Padlock shackle (top curved part)
    shackle_width = 35
    shackle_height = 30
    shackle_x = padlock_x + (padlock_width - shackle_width) // 2
    shackle_y = padlock_y
    
    # Outer shackle
    draw.arc([shackle_x - 5, shackle_y, shackle_x + shackle_width + 5, shackle_y + shackle_height + 10], 
             start=180, end=360, fill=(79, 70, 229, 255), width=8)
    
    # Inner shackle (to create hollow effect)
    draw.arc([shackle_x + 3, shackle_y + 3, shackle_x + shackle_width - 3, shackle_y + shackle_height + 7], 
             start=180, end=360, fill=(255, 255, 255, 255), width=8)
    
    # Keyhole
    keyhole_size = 8
    keyhole_x = padlock_x + padlock_width // 2 - keyhole_size // 2
    keyhole_y = body_top + 15
    draw.ellipse([keyhole_x, keyhole_y, keyhole_x + keyhole_size, keyhole_y + keyhole_size], 
                fill=(255, 255, 255, 255))
    
    # Keyhole slot
    slot_width = 3
    slot_height = 12
    slot_x = padlock_x + padlock_width // 2 - slot_width // 2
    slot_y = keyhole_y + keyhole_size - 2
    draw.rectangle([slot_x, slot_y, slot_x + slot_width, slot_y + slot_height], 
                  fill=(255, 255, 255, 255))
    
    # Add some decorative dots
    dot_color = (199, 210, 254, 255)
    draw.ellipse([center + 80, center + 40, center + 88, center + 48], fill=dot_color)
    draw.ellipse([center + 100, center + 20, center + 106, center + 26], fill=dot_color)
    draw.ellipse([center + 110, center + 60, center + 116, center + 66], fill=dot_color)
    
    # Save the image
    output_path = "assets/icons/app_icon.png"
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    image.save(output_path, "PNG")
    
    print(f"✅ App icon created successfully at: {output_path}")
    print(f"Icon size: {size}x{size} pixels")
    
except ImportError:
    print("❌ PIL (Pillow) not available. Let's create a simpler version...")
    
    # Create a simple fallback using basic tools
    import subprocess
    import os
    
    # Create directory
    os.makedirs("assets/icons", exist_ok=True)
    
    # Use macOS built-in tools to create a simple icon
    # This creates a basic colored square that we can improve later
    applescript = '''
    tell application "System Events"
        return 1
    end tell
    '''
    
    print("📝 Please create a 1024x1024 PNG icon manually and save it as:")
    print("   assets/icons/app_icon.png")
    print("")
    print("Icon should represent file sharing/URL concepts with:")
    print("- Purple/blue gradient background")
    print("- Document or file icon")
    print("- Chain link or network symbol")
    print("- Clean, modern design")

except Exception as e:
    print(f"❌ Error creating icon: {e}")
    print("📝 Please create a 1024x1024 PNG icon manually")
