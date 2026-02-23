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

    // Parse URL once; bail on malformed URLs
    var urlObj;
    try {
        urlObj = new URL(url);
    } catch (e) {
        return;
    }
    var pathname = urlObj.pathname;

    // Cache-first for pose images — scoped to /poses/ to limit cache growth
    var isPoseImage = (
        urlObj.origin === self.location.origin &&
        pathname.indexOf('/poses/') === 0 &&
        IMAGE_PATTERN.test(pathname)
    );

    if (isPoseImage) {
        event.respondWith(
            caches.match(request).then(function (cached) {
                if (cached) return cached;
                return fetch(request).then(function (response) {
                    if (response && (response.ok || response.type === 'opaque')) {
                        var clone = response.clone();
                        event.waitUntil(
                            caches.open(RUNTIME_CACHE).then(function (cache) {
                                return cache.put(request, clone);
                            }).catch(function () {})
                        );
                    }
                    return response;
                }).catch(function (error) {
                    console.warn('[SW] Image fetch failed:', request.url, error);
                    return new Response('', {
                        status: 503,
                        statusText: 'Service Unavailable'
                    });
                });
            })
        );
        return;
    }

    // Cache-first for JS/CSS assets (including CDN)
    if (ASSET_PATTERN.test(pathname)) {
        event.respondWith(
            caches.match(request).then(function (cached) {
                if (cached) return cached;
                return fetch(request).then(function (response) {
                    if (response && (response.ok || response.type === 'opaque')) {
                        var clone = response.clone();
                        event.waitUntil(
                            caches.open(STATIC_CACHE).then(function (cache) {
                                return cache.put(request, clone);
                            }).catch(function () {})
                        );
                    }
                    return response;
                }).catch(function (error) {
                    console.warn('[SW] Fetch failed:', request.url, error);
                    return new Response('', {
                        status: 503,
                        statusText: 'Service Unavailable'
                    });
                });
            })
        );
        return;
    }

    // Network-first with cache fallback for HTML pages
    if (request.headers.get('accept') && request.headers.get('accept').includes('text/html')) {
        event.respondWith(
            fetch(request).then(function (response) {
                if (response && response.ok) {
                    var clone = response.clone();
                    event.waitUntil(
                        caches.open(RUNTIME_CACHE).then(function (cache) {
                            return cache.put(request, clone);
                        }).catch(function () {})
                    );
                }
                return response;
            }).catch(function () {
                return caches.match(request).then(function (cached) {
                    if (cached) return cached;
                    return new Response(
                        '<!doctype html><html><head><meta charset="utf-8"><title>Offline</title></head>' +
                        '<body><h1>You are offline</h1><p>This page is not available offline yet.</p></body></html>',
                        { headers: { 'Content-Type': 'text/html; charset=utf-8' } }
                    );
                });
            })
        );
        return;
    }
});
