# Sri Balaji Rice Mill - Brand Logo Integration

## Logo Details

**File**: `assets/images/sri_balaji_logo.png`

**Design Elements**:
- Green crescent moon shape (representing growth and prosperity)
- Golden wheat stalks (representing rice/grain)
- Traditional temple tower (gopuram) in center
- "SRI BRM" text in golden color
- Professional and culturally appropriate design

---

## Integration Points

### 1. **Splash Screen** ✅
- Logo appears prominently in center (200x200px)
- Circular background with pale green tint
- Smooth fade-in and scale animation
- Mill name "Sri Balaji" below logo
- Subtitle "Boiled and Raw Rice Mill"
- Loading indicator at bottom

**User Experience**: 
- Professional branded first impression
- 2.5 second display time
- Smooth transition to home screen

---

### 2. **Navigation Drawer** ✅
- Logo in circular frame (60x60px)
- White background with green border
- Positioned at top of drawer
- Mill name and owner name below

**User Experience**:
- Consistent branding across navigation
- Easy recognition
- Professional appearance

---

### 3. **Settings Screen - About Section** ✅
- Large logo display (100x100px)
- Circular white background
- Centered in About & Support section
- App name and version below
- Mill details at bottom

**User Experience**:
- Clear brand identity
- Professional presentation
- Easy to recognize in settings

---

## Technical Implementation

### Files Modified:
1. `pubspec.yaml` - Added `assets/images/` to assets
2. `lib/screens/splash_screen.dart` - Logo on splash
3. `lib/screens/home_screen.dart` - Logo in drawer
4. `lib/screens/settings_screen.dart` - Logo in about section

### Asset Location:
```
mobile/flutter_app/
  └── assets/
      └── images/
          └── sri_balaji_logo.png
```

### Code Pattern:
```dart
Image.asset(
  'assets/images/sri_balaji_logo.png',
  fit: BoxFit.contain,
)
```

---

## Brand Consistency

### Color Palette (from logo):
- **Primary Green**: `#2E7D32` (crescent, used in app theme)
- **Golden Yellow**: `#FFA000` (wheat, text)
- **White**: Background and highlights

### Typography:
- Logo uses decorative/traditional font
- App uses Google Fonts (Inter/Roboto) for readability
- Maintains professional yet traditional feel

---

## Future Enhancements

### Potential Uses:
1. **App Icon**: Use logo as launcher icon
2. **PDF Reports**: Add logo to Excel/PDF headers
3. **Email Signature**: Include in email templates
4. **WhatsApp Messages**: Attach logo to order messages
5. **Print Materials**: Use for invoices and receipts

### Variations Needed:
- Square version for app icon (512x512px)
- Horizontal version for headers
- Monochrome version for printing
- Favicon for web version

---

## Brand Guidelines

### DO:
✅ Use logo on white or light backgrounds
✅ Maintain aspect ratio
✅ Keep clear space around logo
✅ Use high-resolution version for print

### DON'T:
❌ Stretch or distort logo
❌ Change colors
❌ Add effects or shadows
❌ Use on busy backgrounds
❌ Make it too small (min 40x40px)

---

## Summary

The Sri Balaji Rice Mill logo has been successfully integrated throughout the RiceAgent application, providing:

1. **Professional Branding**: Consistent visual identity
2. **Cultural Relevance**: Traditional temple tower design
3. **Recognition**: Easy to identify across all screens
4. **Trust**: Professional appearance builds confidence

The logo now appears in all key touchpoints:
- ✅ Splash screen (first impression)
- ✅ Navigation drawer (persistent presence)
- ✅ Settings/About (brand information)

**Next Step**: Deploy to phone to see the branded experience!
