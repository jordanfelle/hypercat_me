/**
 * Service Worker for hypercat.me
 * Enables offline support for the poses page.
 */
'use strict';

var CACHE_VERSION = 'v1';
var STATIC_CACHE = 'hypercat-static-' + CACHE_VERSION;
var RUNTIME_CACHE = 'hypercat-runtime-' + CACHE_VERSION;

var IMAGE_PATTERN = /\.(webp|jpg|jpeg|png|gif|svg)(\?.*)?$/;
var ASSET_PATTERN = /\.(css|js)(\?.*)?$/;

// CDN libraries required by the poses page - pre-cache on install
var PRECACHE_URLS = [
    'https://cdnjs.cloudflare.com/ajax/libs/justifiedGallery/3.8.1/css/justifiedGallery.min.css',
    'https://cdnjs.cloudflare.com/ajax/libs/glightbox/3.3.1/css/glightbox.min.css',
    'https://cdnjs.cloudflare.com/ajax/libs/jquery/3.7.1/jquery.min.js',
    'https://cdnjs.cloudflare.com/ajax/libs/justifiedGallery/3.8.1/js/jquery.justifiedGallery.min.js',
    'https://cdnjs.cloudflare.com/ajax/libs/glightbox/3.3.1/js/glightbox.min.js'
];

self.addEventListener('install', function (event) {
    event.waitUntil(
        caches.open(STATIC_CACHE).then(function (cache) {
            // Pre-cache each CDN asset individually so one failure doesn't block all
            return Promise.all(
                PRECACHE_URLS.map(function (url) {
                    return cache.add(url).catch(function () {
                        console.warn('[SW] Failed to pre-cache:', url);
                    });
                })
            );
        }).then(function () {
            return self.skipWaiting();
        })
    );
});

self.addEventListener('activate', function (event) {
    event.waitUntil(
        caches.keys().then(function (cacheNames) {
            return Promise.all(
                cacheNames.filter(function (name) {
                    return name.startsWith('hypercat-') &&
                        name !== STATIC_CACHE &&
                        name !== RUNTIME_CACHE;
                }).map(function (name) {
                    return caches.delete(name);
                })
            );
        }).then(function () {
            return self.clients.claim();
        })
    );
});

self.addEventListener('fetch', function (event) {
    var request = event.request;
    var url = request.url;

    // Only handle GET requests over http(s)
    if (request.method !== 'GET') return;
    if (!url.startsWith('http')) return;

    // Cache-first for images (pose images, etc.)
    if (IMAGE_PATTERN.test(url)) {
        event.respondWith(
            caches.match(request).then(function (cached) {
                if (cached) return cached;
                return fetch(request).then(function (response) {
                    if (response && response.status === 200) {
                        var clone = response.clone();
                        caches.open(RUNTIME_CACHE).then(function (cache) {
                            cache.put(request, clone);
                        });
                    }
                    return response;
                });
            })
        );
        return;
    }

    // Cache-first for JS/CSS assets (including CDN)
    if (ASSET_PATTERN.test(url)) {
        event.respondWith(
            caches.match(request).then(function (cached) {
                if (cached) return cached;
                return fetch(request).then(function (response) {
                    if (response && response.status === 200) {
                        var clone = response.clone();
                        caches.open(STATIC_CACHE).then(function (cache) {
                            cache.put(request, clone);
                        });
                    }
                    return response;
                });
            })
        );
        return;
    }

    // Network-first with cache fallback for HTML pages
    if (request.headers.get('accept') && request.headers.get('accept').includes('text/html')) {
        event.respondWith(
            fetch(request).then(function (response) {
                if (response && response.status === 200) {
                    var clone = response.clone();
                    caches.open(RUNTIME_CACHE).then(function (cache) {
                        cache.put(request, clone);
                    });
                }
                return response;
            }).catch(function () {
                return caches.match(request);
            })
        );
        return;
    }
});
