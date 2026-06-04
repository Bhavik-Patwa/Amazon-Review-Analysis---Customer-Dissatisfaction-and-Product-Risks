-- Creating filtered product and review tables for the final approved category scope
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.filtered_category_products` AS
-- Defining trusted main categories for each selected Amazon category
WITH allowed_main_categories AS (
    SELECT 'Electronics' AS category_name, main_category
    FROM UNNEST([
        'Computers',
        'All Electronics',
        'Camera & Photo',
        'Cell Phones & Accessories',
        'Home Audio & Theater',
        'Car Electronics',
        'GPS & Navigation',
        'Amazon Devices',
        'Portable Audio & Accessories',
        'Apple Products',
        'Amazon Fire TV',
        'Fire Phone'
    ]) AS main_category

    UNION ALL

    SELECT 'Home_and_Kitchen' AS category_name, main_category
    FROM UNNEST([
        'Amazon Home',
        'Tools & Home Improvement',
        'Appliances'
    ]) AS main_category

    UNION ALL

    SELECT 'Beauty_and_Personal_Care' AS category_name, main_category
    FROM UNNEST([
        'All Beauty',
        'Health & Personal Care',
        'Premium Beauty'
    ]) AS main_category

    UNION ALL

    SELECT 'Books' AS category_name, main_category
    FROM UNNEST([
        'Books',
        'Buy a Kindle',
        'Audible Audiobooks'
    ]) AS main_category

    UNION ALL

    SELECT 'Movies_and_TV' AS category_name, main_category
    FROM UNNEST([
        'Movies & TV',
        'Prime Video'
    ]) AS main_category
),
-- Defining detailed category terms that identify relevant products inside each category
allowed_category_entities AS (
    SELECT 'Electronics' AS category_name, entity
    FROM UNNEST([
        'Computers',
        'Computer & Tablet Accessories',
        'Computer Accessories & Peripherals',
        'Computer Components',
        'Laptops',
        'Gaming Laptops',
        'Desktops',
        'Gaming Desktops',
        'Gaming Computers',
        'Monitors',
        'Gaming Monitors',
        'Motherboards',
        'Processors',
        'Graphics Cards',
        'Memory',
        'Hard Drives & Digital Storage',
        'External Hard Drives',
        'Internal Hard Drives',
        'External Solid State Drives',
        'Internal Solid State Drives',
        'USB Flash Drives',
        'Memory Cards',
        'SD Cards',
        'Micro SD Cards',
        'Networking',
        'Routers',
        'Modems',
        'Network Adapters',
        'Wireless Access Points',
        'Network Cameras',
        'Webcams',
        'Keyboards',
        'Gaming Keyboards',
        'Mice',
        'Gaming Mice',
        'Headphones',
        'Earbud Headphones',
        'Over-Ear Headphones',
        'On-Ear Headphones',
        'Open-Ear Headphones',
        'Bluetooth Headsets',
        'Bluetooth Speakers',
        'Speakers',
        'Computer Speakers',
        'Sound Bars',
        'Subwoofers',
        'Home Audio',
        'Home Theater',
        'Home Theater Systems',
        'Receivers',
        'Receivers & Amplifiers',
        'AV Receivers & Amplifiers',
        'Televisions',
        'TV Accessories - Home',
        'LED & LCD TVs',
        'OLED TVs',
        'QLED TVs',
        'TV Mounts, Stands & Turntables',
        'Streaming Media Players',
        'Projector',
        'Video Projectors',
        'DVD Players',
        'Blu-ray Players',
        'Blu-ray Players & Recorders',
        'Cameras',
        'Camera & Photo',
        'Digital Cameras',
        'DSLR Cameras',
        'Mirrorless Cameras',
        'Point & Shoot Digital Cameras',
        'Film Cameras',
        'Instant Cameras',
        'Camcorders',
        'Camera Accessories',
        'Camera Batteries',
        'Camera Cases',
        'Camera Lenses',
        'Camera Mounts & Clamps',
        'Camera Tripods',
        'Tripods & Monopods',
        'Binoculars',
        'Microscopes',
        'Telescopes',
        'Cell Phones & Accessories',
        'Phone & Tablet Accessories',
        'Tablet Accessories',
        'Tablets',
        'Tablet PCs',
        'Smartwatches',
        'Wearable Technology',
        'GPS, Finders & Accessories',
        'GPS Trackers',
        'Vehicle GPS',
        'Marine Electronics',
        'Car Audio',
        'Car Stereo Receivers',
        'Car Electronics',
        'Radar Detectors',
        'Two-Way Radios',
        'CB Radios',
        'Surveillance Cameras',
        'Surveillance Systems',
        'Security & Surveillance',
        'Video Surveillance',
        'Smart Home Security & Lighting',
        'Smart Plugs',
        'Smart Lighting',
        'Cables',
        'HDMI Cables',
        'USB Cables',
        'Ethernet Cables',
        'SATA Cables',
        'Adapters',
        'Chargers',
        'Power Adapters',
        'Power Supplies & Chargers',
        'Power Cables',
        'Batteries',
        'Battery Chargers',
        'Docking Stations',
        'eBook Readers',
        'eBook Readers & Accessories'
    ]) AS entity

    UNION ALL

    SELECT 'Home_and_Kitchen' AS category_name, entity
    FROM UNNEST([
        'Home & Kitchen',
        'Kitchen & Dining',
        'Kitchen',
        'Furniture',
        'Home Decor',
        'Home Décor Accents',
        'Bedding',
        'Bath',
        'Bathroom Accessories',
        'Bathroom Storage & Organization',
        'Storage & Organization',
        'Laundry Storage & Organization',
        'Kitchen Storage & Organization',
        'Food Storage',
        'Cookware',
        'Cookware Sets',
        'Bakeware',
        'Baking & Cookie Sheets',
        'Dinnerware',
        'Dinnerware Sets',
        'Flatware',
        'Drinkware',
        'Serveware',
        'Barware',
        'Coffee & Tea',
        'Coffee Makers',
        'Espresso Machines',
        'Tea Kettles',
        'Blenders',
        'Air Fryers',
        'Toasters',
        'Toaster Ovens',
        'Microwave Ovens',
        'Pressure Cookers',
        'Slow Cookers',
        'Rice Cookers',
        'Juicers',
        'Mixers',
        'Food Processors',
        'Vacuum Sealers',
        'Kitchen Tools, Gadgets & Cutlery',
        'Knives',
        'Knife Sets',
        'Cutting Boards',
        'Pots & Pans',
        'Plates',
        'Bowls',
        'Cups',
        'Mugs',
        'Wine Glasses',
        'Wine Racks',
        'Kitchen Trash Cans',
        'Vacuums',
        'Robotic Vacuums',
        'Steam Cleaners',
        'Air Purifiers',
        'Humidifiers',
        'Dehumidifiers',
        'Fans',
        'Space Heaters',
        'Air Conditioners',
        'Heating, Cooling & Air Quality',
        'Mattresses',
        'Bed Frames',
        'Beds',
        'Pillows',
        'Comforters',
        'Sheets & Pillowcases',
        'Blankets & Throws',
        'Towels',
        'Shower Curtains',
        'Rugs',
        'Area Rugs',
        'Curtains & Drapes',
        'Window Treatments',
        'Lamps & Lighting',
        'Wall Art',
        'Mirrors',
        'Clocks',
        'Candles',
        'Candleholders',
        'Vases',
        'Artificial Plants & Flowers',
        'Planters',
        'Shelving',
        'Cabinets',
        'Bookcases',
        'Desks',
        'Home Office Chairs',
        'Home Office Desk Chairs',
        'Home Office Furniture',
        'Dining Room Furniture',
        'Living Room Furniture',
        'Bedroom Furniture',
        'Sofas',
        'Chairs',
        'Tables',
        'Coffee Tables',
        'TV & Media Furniture'
    ]) AS entity

    UNION ALL

    SELECT 'Beauty_and_Personal_Care' AS category_name, entity
    FROM UNNEST([
        'Beauty & Personal Care',
        'Skin Care',
        'Hair Care',
        'Makeup',
        'Fragrance',
        'Perfumes & Fragrances',
        'Nail Care',
        'Oral Care',
        'Shaving & Hair Removal',
        'Men’s Grooming',
        'Bath & Body',
        'Sunscreens & Tanning Products',
        'Hair Color',
        'Styling Products',
        'Styling Tools & Appliances',
        'Hair Dryers',
        'Curling Irons & Wands',
        'Straighteners',
        'Clippers & Trimmers',
        'Electric Shavers',
        'Razors & Blades',
        'Beard Care',
        'Shampoo',
        'Conditioners',
        'Shampoo & Conditioner',
        'Hair Brushes',
        'Hair Accessories',
        'Hair Extensions',
        'Wigs',
        'Cleansers',
        'Skin Cleansers',
        'Moisturizers',
        'Face Moisturizers',
        'Serums',
        'Toners & Astringents',
        'Masks',
        'Acne Treatment Devices',
        'Wrinkle & Anti-Aging Devices',
        'Facial Cleansing Brushes',
        'Body Washes',
        'Body Lotions',
        'Body Scrubs',
        'Deodorants',
        'Antiperspirants',
        'Lipstick',
        'Lip Glosses',
        'Lip Liners',
        'Foundation',
        'Concealer',
        'Blush',
        'Bronzers',
        'Highlighters & Luminizers',
        'Eyeshadow',
        'Eyeliner',
        'Mascara',
        'Eyebrow Color',
        'Makeup Brushes & Tools',
        'Makeup Remover',
        'Nail Polish',
        'Nail Polish Remover',
        'Nail Tools',
        'Nail Art & Polish',
        'Foot, Hand & Nail Care',
        'Essential Oils',
        'Bath Bombs',
        'Bath Salts',
        'Shaving Creams, Lotions & Gels',
        'Waxing',
        'Waxing Kits',
        'Toothpaste',
        'Mouthwash & Breath Fresheners',
        'Power Toothbrushes',
        'Manual Toothbrushes'
    ]) AS entity

    UNION ALL

    SELECT 'Books' AS category_name, entity
    FROM UNNEST([
        'Books',
        'Children’s Books',
        'Teen & Young Adult',
        'Literature & Fiction',
        'Fiction',
        'Nonfiction',
        'Mystery, Thriller & Suspense',
        'Science Fiction & Fantasy',
        'Science Fiction',
        'Fantasy',
        'Romance',
        'Comics & Graphic Novels',
        'Manga',
        'Biographies & Memoirs',
        'History',
        'Business & Money',
        'Computers & Technology',
        'Computer Science',
        'Programming',
        'Python',
        'SQL',
        'Data Analytics',
        'AI & Machine Learning',
        'Databases & Big Data',
        'Cloud Computing',
        'Web Development',
        'Software Development',
        'Mathematics',
        'Science & Math',
        'Physics',
        'Chemistry',
        'Biology',
        'Engineering',
        'Medicine',
        'Health, Fitness & Dieting',
        'Psychology',
        'Self-Help',
        'Education & Teaching',
        'Study Aids',
        'Test Preparation',
        'Law',
        'Politics & Government',
        'Religion & Spirituality',
        'Cookbooks, Food & Wine',
        'Arts & Photography',
        'Crafts, Hobbies & Home',
        'Travel',
        'Sports & Outdoors',
        'Parenting & Relationships',
        'Reference',
        'Foreign Language Study',
        'Social Sciences',
        'Economics',
        'Finance',
        'Philosophy',
        'Poetry',
        'Drama & Plays'
    ]) AS entity

    UNION ALL

    SELECT 'Movies_and_TV' AS category_name, entity
    FROM UNNEST([
        'Movies & TV',
        'Prime Video',
        'DVD',
        'Blu-ray',
        'Box Sets',
        'Action & Adventure',
        'Comedy',
        'Drama',
        'Horror',
        'Sci-Fi & Fantasy',
        'Science Fiction',
        'Fantasy',
        'Documentary',
        'Animation',
        'Anime',
        'Kids & Family',
        'TV Series',
        'TV & Miniseries',
        'Musicals',
        'Music Videos & Concerts',
        'Music & Performing Arts',
        'Foreign Films',
        'International',
        'Art House & International',
        'Mystery & Suspense',
        'Thriller & Suspense',
        'Romance',
        'Western',
        'Military & War',
        'History',
        'Faith & Spirituality',
        'Sports',
        'Fitness',
        'Exercise & Fitness',
        'Educational',
        'Special Interest',
        'Stand Up',
        'Reality TV',
        'British Television',
        'Classic TV',
        'Independently Distributed',
        'Indie & Art House'
    ]) AS entity
),
-- Removing products that belong to unrelated or contaminated category areas
excluded_main_categories AS (
    SELECT 'Electronics' AS category_name, main_category
    FROM UNNEST([
        'Books',
        'Movies & TV',
        'Gift Cards',
        'Digital Music',
        'Magazine Subscriptions',
        'Audible Audiobooks',
        'Collectible Coins',
        'Collectibles & Fine Art',
        'Unique Finds'
    ]) AS main_category

    UNION ALL

    SELECT 'Home_and_Kitchen' AS category_name, main_category
    FROM UNNEST([
        'Audible Audiobooks',
        'Gift Cards',
        'Digital Music',
        'Books',
        'Buy a Kindle',
        'Movies & TV',
        'Collectible Coins',
        'Sports Collectibles',
        'Software'
    ]) AS main_category

    UNION ALL

    SELECT 'Beauty_and_Personal_Care' AS category_name, main_category
    FROM UNNEST([
        'Gift Cards',
        'Movies & TV',
        'Digital Music',
        'Video Games',
        'Software',
        'Books',
        'Buy a Kindle',
        'Collectible Coins',
        'Collectibles & Fine Art',
        'Entertainment',
        'Unique Finds'
    ]) AS main_category

    UNION ALL

    SELECT 'Books' AS category_name, main_category
    FROM UNNEST([
        'Gift Cards'
    ]) AS main_category

    UNION ALL

    SELECT 'Movies_and_TV' AS category_name, main_category
    FROM UNNEST([
        'Books',
        'Gift Cards',
        'Collectible Coins',
        'Unique Finds'
    ]) AS main_category
),
-- Selecting products that match the approved main category rules
main_category_matches AS (
    SELECT
        products.category_name,
        products.parent_asin,
        products.product_title,
        products.main_category,
        products.store,
        products.average_rating,
        products.rating_number,
        products.price_amount,
        products.features_json,
        products.description_json,
        products.details_json,
        CAST(NULL AS STRING) AS matched_category_entity
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.products` AS products
    INNER JOIN allowed_main_categories AS allowed
        ON products.category_name = allowed.category_name
       AND products.main_category = allowed.main_category
),
-- Selecting products that match approved detailed category entities
category_entity_matches AS (
    SELECT
        products.category_name,
        products.parent_asin,
        products.product_title,
        products.main_category,
        products.store,
        products.average_rating,
        products.rating_number,
        products.price_amount,
        products.features_json,
        products.description_json,
        products.details_json,
        category_element AS matched_category_entity
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.products` AS products
    CROSS JOIN UNNEST(
        IFNULL(
            JSON_VALUE_ARRAY(products.categories_json),
            ARRAY<STRING>[]
        )
    ) AS category_element
    INNER JOIN allowed_category_entities AS allowed
        ON products.category_name = allowed.category_name
       AND category_element = allowed.entity
),
-- Combining all approved product matches before final filtering
matched_products AS (
    SELECT * FROM main_category_matches
    UNION ALL
    SELECT * FROM category_entity_matches
)



-- Building the final filtered product table after removing excluded category contamination
SELECT
    matched.category_name,
    matched.parent_asin,
    matched.product_title,
    matched.main_category,
    matched.store,
    matched.average_rating,
    matched.rating_number,
    matched.price_amount,
    COALESCE(
        TO_JSON_STRING(
            ARRAY_AGG(DISTINCT matched.matched_category_entity IGNORE NULLS ORDER BY matched.matched_category_entity)
        ),
        '[]'
    ) AS categories_json,
    matched.features_json,
    matched.description_json,
    matched.details_json
FROM matched_products AS matched
LEFT JOIN excluded_main_categories AS excluded
    ON matched.category_name = excluded.category_name
   AND NULLIF(TRIM(matched.main_category), '') = excluded.main_category
WHERE excluded.main_category IS NULL
GROUP BY
    matched.category_name,
    matched.parent_asin,
    matched.product_title,
    matched.main_category,
    matched.store,
    matched.average_rating,
    matched.rating_number,
    matched.price_amount,
    matched.features_json,
    matched.description_json,
    matched.details_json;


-- Keeping only reviews linked to products that passed the filtered category policy
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.filtered_category_reviews` AS
SELECT
    reviews.category_name,
    reviews.asin,
    reviews.parent_asin,
    reviews.user_id,
    reviews.rating,
    reviews.helpful_vote,
    reviews.verified_purchase,
    reviews.review_title,
    reviews.review_text,
    reviews.review_timestamp_ms,
    reviews.review_timestamp_utc,
    reviews.review_date,
    reviews.review_month
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.reviews` AS reviews
INNER JOIN `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.filtered_category_products` AS products
    ON reviews.category_name = products.category_name
   AND reviews.parent_asin = products.parent_asin;