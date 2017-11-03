(function() {

  function getCorsUrl(url) {
    var proxy = window.CORS_PROXY || 'https://cors-anywhere.herokuapp.com';
    return proxy + '/' + url;
  }

  function checkNested(obj, levels) {
    for (var i=0; i<levels.length; i++) {
      if (!obj || !obj.hasOwnProperty(levels[i])) {
        return false;
      }
      obj = obj[levels[i]];
    }
    return true;
  }

  function loadScripts(windowProperty, scripts) {
    if (checkNested(window, windowProperty.split('.'))) {
      return $.when();
    } else {
      scripts = $.isArray(scripts) ? scripts : [scripts];
      var promises = $.map(scripts, function(script) {
        return $.ajax({
          dataType: 'script',
          cache: true,
          url: script[0] === '/' ? ((window.BASE_URL || '') + script) : script
        });
      });
      return $.when.apply($, promises).then(function() {
        if (!checkNested(window, windowProperty.split('.'))) {
          var msg = 'window.' + windowProperty + ' is still undefined after loading '
            + scripts.join(', ');
          console.error(msg);
          return $.Deferred().reject(msg);
        }
      });
    }
  }

  function loadScriptsInOrder(propertyScriptsPairs) {
    return propertyScriptsPairs.reduce(function(promise, propertyScriptsPair) {
      return promise.then(function() {
        return loadScripts(propertyScriptsPair[0], propertyScriptsPair[1]);
      });
    }, $.when());
  }

  $(document).ready(function setupPhotoSpheres() {
    function loadPhotoSphereScripts() {
      return loadScriptsInOrder([
        ['THREE', 'https://cdn.jsdelivr.net/npm/three@0.87.1/build/three.min.js'],
        ['PhotoSphereViewer', [
          'https://cdn.jsdelivr.net/npm/d.js@0.7.5/lib/D.min.js',
          'https://cdn.jsdelivr.net/npm/uevent@1.0.0/uevent.min.js',
          'https://cdn.jsdelivr.net/npm/dot@1.1.2/doT.min.js',
          'https://cdn.jsdelivr.net/npm/photo-sphere-viewer@3.2.3/dist/photo-sphere-viewer.min.js',
          '/assets/js/mrdoob/three.js/master/examples/js/renderers/CanvasRenderer.js',
          '/assets/js/mrdoob/three.js/master/examples/js/renderers/Projector.js',
          '/assets/js/mrdoob/three.js/master/examples/js/controls/DeviceOrientationControls.js']]
      ]);
    }

    function setupPhotoSphereViewer(container) {
      $(container).one('click', function() {
        $(this).empty();
        var viewer = PhotoSphereViewer({
          container: this,
          panorama: getCorsUrl($(this).attr('data-url')),
          caption: $(this).attr('data-caption'),
          gyroscope: true
        });
        viewer.getNavbarButton('markers').hide();
      });
    }
    var $containers = $('.photosphere-viewer');
    if ($containers.length > 0) {
      loadPhotoSphereScripts().then(function() {
        $containers.each(function() {
          setupPhotoSphereViewer(this);
        });
      });
    }
  });

  $(document).ready(function setupGeoJsons() {
    function loadGoogleMapsScripts() {
      return $.when(
        loadScripts('google.maps.Map', 'https://maps.googleapis.com/maps/api/js?key=' + window.GOOGLE_MAPS_KEY),
        loadScripts('jQuery.prototype.fullScreen', 'https://cdn.jsdelivr.net/npm/jquery-fullscreen-plugin@1.0.0/jquery.fullscreen-min.min.js')
      );
    }

    var ICON_INACTIVE = 'https://maps.gstatic.com/mapfiles/ms2/micons/red-dot.png';
    var ICON_ACTIVE = 'https://maps.gstatic.com/mapfiles/ms2/micons/green-dot.png';

    if (window.SHOW_MAP !== undefined && !window.SHOW_MAP) {
      return;
    }
    var annotatedElements = $('[data-geo-json]');
    if (annotatedElements.length === 0) {
      return;
    }

    loadGoogleMapsScripts().then(function() {
      // find an existing map container or make one and append it into sidebar
      var $container = $('#map');
      if ($container.length === 0) {
        $container = $('<div class="google-map">');
        $('#main .sidebar').first().append($container);
      }
      var mapOptions = $.extend({zoom: 1, center: {lat: 0, lng: 0}}, window.MAP_OPTIONS);
      var map = new google.maps.Map($container[0], mapOptions);
      var bounds = new google.maps.LatLngBounds();

      map.data.setStyle(function(feature) {
        if (feature.getProperty('active')) {
          return {icon: ICON_ACTIVE, zIndex: 10};
        } else {
          return {icon: ICON_INACTIVE, zIndex: 0};
        }
      });

      annotatedElements.each(function() {
        var geoJson = JSON.parse(this.dataset.geoJson);
        map.data.addGeoJson(geoJson, {idPropertyName: 'id'});

        // extend bounds
        $.each(geoJson.features, function(i, feature) {
          var cs = feature.geometry.coordinates;
          if (cs.length === 0) {
            return;
          }
          if (typeof cs[0] === 'number') {
            bounds.extend({lng: cs[0], lat: cs[1]});
          } else if ($.isArray(cs[0])) {
            $.each(cs, function(i, lngLat) {
              bounds.extend({lng: lngLat[0], lat: lngLat[1]});
            });
          }
        });
      });
      map.fitBounds(bounds);

      $('[data-geo-json-id]').on('mouseover', function() {
        var feature = map.data.getFeatureById(this.dataset.geoJsonId);
        if (feature) {
          var geometry = feature.getGeometry();
          if (geometry.getType() === 'Point') {
            map.panTo(geometry.get());
          }
          feature.setProperty('active', true);
        }
      }).on('mouseout', function() {
        var feature = map.data.getFeatureById(this.dataset.geoJsonId);
        if (feature) {
          feature.setProperty('active', false);
        }
      });

      var infoWindow = new google.maps.InfoWindow();
      map.addListener('click', function() {
        infoWindow.close();
      });
      map.data.addListener('click', function(event) {
        var feature = event.feature;
        if (feature) {
          openFeaturePopup(feature);
        }
      });
      map.data.addListener('mouseover', function(event) {
        var feature = event.feature;
        if (feature) {
          feature.setProperty('active', true);
        }
      });
      map.data.addListener('mouseout', function(event) {
        var feature = event.feature;
        if (feature) {
          feature.setProperty('active', false);
        }
      });

      function openFeaturePopup(feature) {
        var icon = feature.getProperty('icon');
        if (!icon) {
          return;
        }
        var id = feature.getId();
        var position = feature.getGeometry().getType() === 'Point' ? feature.getGeometry().get() : map.getCenter();
        var $img = $('<img class="google-map__icon">').attr('src', icon).on('click', function() {
          var $referencedElement = $('[data-geo-json-id="' + id + '"]');
          if (!$referencedElement) {
            return;
          }
          var listeningTo = $._data($referencedElement[0], 'events');
          if (listeningTo && listeningTo.click) {
            $referencedElement.trigger('click');
          } else if ($referencedElement.is('a')) {
            $referencedElement.trigger('click');
          } else if ($referencedElement.find('a').length > 0) {
            $referencedElement.find('a').first().trigger('click');
          } else {
            $(document).fullScreen(false);
            $.smoothScroll({scrollTarget: $referencedElement});
          }
        });
        infoWindow.setContent($img[0]);
        infoWindow.setPosition(position);
        infoWindow.open(map);
      }
    });
  });

  $(document).ready(function configureExternalLinks() {
    var urlRegExp = /https?:\/\/(.*?)(\/|$)/i;
    $('a[href]').each(function() {
      if ($(this).text().trim()) {
        $(this).addClass('has-text');
      }
      var match = urlRegExp.exec(this.href);
      if (match) {
        var host = match[1];
        if (host !== window.location.host) {
          $(this).attr('target', '_blank')
            .attr('rel', 'noopener');
        }
      }
    });
  });

  $(document).ready(function configureAccordionJs() {
    // http://accordionjs.zerowp.com/
    var $accordionjs = $('.accordionjs');
    if ($accordionjs.length > 0) {
      loadScripts('jQuery.prototype.accordionjs', '/assets/js/awps/Accordion.JS/master/accordion.js')
        .then(function() {
          $accordionjs.accordionjs({activeIndex: false});
        });
    }
  });

  $(document).ready(function setupImagePopups() {
    function getImageSrc($img) {
      var srcset = $img.attr('data-srcset') || $img.attr('srcset');
      if (srcset) {
        var ww = $(window).width();
        var specs = srcset.split(/\s*,\s*/);
        var regexp = /(\S+)\s+(([0-9]+)w)?/;
        var srcWidthPairs = specs.map(function(spec) {
          var match = regexp.exec(spec);
          if (match) {
            return [match[1], match[3]];
          }
        });
        var srcWidthPair = srcWidthPairs.find(function(srcWidthPair) {
          return !srcWidthPair[1] || srcWidthPair[1] > ww;
        });
        if (srcWidthPair) {
          return srcWidthPair[0];
        }
      }
      return $img.attr('src');
    }

    // http://dimsemenov.com/plugins/magnific-popup/documentation.html
    $(".gphoto_entry.image").magnificPopup({
      type: 'image',
      tLoading: 'Loading image #%curr%...',
      gallery: {
        enabled: true,
        navigateByImgClick: true,
        preload: [0,1] // Will preload 0 - before current, and 1 after the current image
      },
      image: {
        titleSrc: function(item) {
          var $img = item.el.find('img');
          return $img.attr('data-caption');
        }
      },
      callbacks: {
        elementParse: function(item) {
          var $img = item.el.find('img');
          item.src = getImageSrc($img);
        },
        resize: function() {
          var item = $.magnificPopup.instance.currItem;
          if (item) {
            var src = item.src;
            item.src = getImageSrc(item.el.find('img'));
            if (src !== item.src) {
              $.magnificPopup.instance.updateItemHTML();
            }
          }
        }
      },
      overflowY: 'hidden',
      closeOnContentClick: true,
      midClick: true // allow opening popup on middle mouse click. Always set it to true if you don't provide alternative source.
    });
  });

  $(document).ready(function setupResponsivelyLazyImages() {
    if ($('.responsively-lazy').length > 0) {
      loadScripts('responsivelyLazy', 'https://cdn.jsdelivr.net/npm/responsively-lazy@2.0.2/responsivelyLazy.min.js');
    }
  });
}());
