# itemly-app
Product Catalog

A lightweight, offline Android app for keeping product information in one searchable place: names, descriptions, prices, custom specifications, photos and videos. Built with Flutter and SQLite.

It replaces digging through photo galleries, chat history and scattered notes. Save a product once, then find it again by typing a few letters.

This is a product catalog, not an inventory system. There is no stock tracking, ordering or accounting by design.

Features

Products

Add, edit and delete products
Name, description, price (Indonesian Rupiah), optional category and notes
Flexible specifications: add any attribute you like (colour, size, material, feature, ...) instead of fixed fields
Multiple photos (camera or gallery) and videos, with preview, full-screen viewing and pinch-to-zoom
Created and updated dates are recorded automatically

Search

Instant local search across name, description, specifications, notes, price and category
Partial matching: rel, laci and soft closing all find "Rel Laci"
Unit-tolerant: 40cm matches a spec written as 40 cm
Simple Indonesian ↔ English synonyms (for example hitam finds black)
Filter by category and sort by newest, oldest or name (A–Z, Z–A)

Offline and local

Everything is stored on the device, with no account and no internet connection needed
Photos are resized (max 1600 px, 80% quality) and copied into the app's private storage to save space
Screens
Home: search bar, category chips, sort menu, product grid and an Add button
Add / Edit product: form with dynamic specification rows and media pickers
Product detail: photo gallery, price, description, specifications, videos, notes and dates
Full-screen viewers: swipeable zoomable photos and a video player
Tech stack
Flutter (Dart), Material 3
sqflite for the local SQLite database
image_picker for the camera and gallery
video_player for playback
photo_view for zoomable photos
path, path_provider, uuid
