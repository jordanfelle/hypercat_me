(function() {
    'use strict';

    var lightbox = null;

    function initGallery(selector) {
        // Initialize justified gallery for visible grids
        if (window.jQuery && jQuery.fn.justifiedGallery) {
            var target = selector ? jQuery(selector) : jQuery('.poses-grid');
            try { target.justifiedGallery('destroy'); } catch (e) {}
            target.justifiedGallery({
                rowHeight: 220,
                margins: 16,
                lastRow: 'nojustify',
                captions: false,
                imagesSelector: 'img'
            });
        }

        // Reinitialize GLightbox for currently visible images
        if (!window.GLightbox) return;
        if (lightbox) {
            lightbox.destroy();
        }
        lightbox = GLightbox({
            selector: '.poses-section:not(.poses-hidden) .poses-grid a',
            touchNavigation: true,
            loop: true,
            slideEffect: 'slide'
        });

        // Style description as badge on image
        function styleDescription() {
            var allSlides = document.querySelectorAll('.gslide');
            Array.prototype.forEach.call(allSlides, function(slide) {
                var desc = slide.querySelector('.gslide-description');
                var media = slide.querySelector('.gslide-media');
                if (desc && media && desc.parentElement !== media) {
                    media.appendChild(desc);
                }
            });
        }

        lightbox.on('open', function() { setTimeout(styleDescription, 150); });
        lightbox.on('slide_changed', function() { setTimeout(styleDescription, 50); });
    }

    function setFilter(filter) {
        var sections = document.querySelectorAll('.poses-section');
        Array.prototype.forEach.call(sections, function(section) {
            var category = section.getAttribute('data-category');
            if (filter === 'all' || filter === category) {
                section.classList.remove('poses-hidden');
            } else {
                section.classList.add('poses-hidden');
            }
        });

        // Update active button state
        var buttons = document.querySelectorAll('.poses-nav-btn');
        Array.prototype.forEach.call(buttons, function(btn) {
            var isActive = btn.getAttribute('data-filter') === filter;
            btn.classList.toggle('active', isActive);
            btn.setAttribute('aria-pressed', isActive ? 'true' : 'false');
        });

        // Reinitialize gallery for newly visible sections
        if (filter === 'all') {
            initGallery(null);
        } else {
            initGallery('#poses-grid-' + filter);
        }
    }

    function initFilter() {
        var buttons = document.querySelectorAll('.poses-nav-btn');
        Array.prototype.forEach.call(buttons, function(btn) {
            btn.addEventListener('click', function() {
                var filter = this.getAttribute('data-filter');
                setFilter(filter);
            });
        });
    }

    function initBackToTop() {
        var backToTop = document.querySelector('.poses-back-to-top');
        if (!backToTop) return;

        function toggleVisibility() {
            var scrollTop = window.scrollY !== undefined ? window.scrollY : window.pageYOffset;
            if (scrollTop > 200) {
                backToTop.classList.add('is-visible');
            } else {
                backToTop.classList.remove('is-visible');
            }
        }

        backToTop.addEventListener('click', function() {
            try {
                window.scrollTo({ top: 0, behavior: 'smooth' });
            } catch (err) {
                window.scrollTo(0, 0);
            }
        });

        toggleVisibility();
        window.addEventListener('scroll', toggleVisibility, { passive: true });
    }

    function init() {
        initGallery(null);
        initFilter();
        initBackToTop();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
