var idx = lunr(function () {
  this.field('title', {boost: 10})
  this.field('excerpt')
  this.field('categories')
  this.field('tags')
  this.ref('id')
});



  
  
    idx.add({
      title: "Traveling to Munich",
      excerpt: "Bringing a 29-er mountain bike onto an airplane is usually a nerve-wracking experience.\n\n",
      categories: [],
      tags: ["SeaTac","WA","Longford","England","United Kingdom","München","BY","Germany","Image"],
      id: 0
    });
    
  
    idx.add({
      title: "Munich 1",
      excerpt: "First order of business upon landing in a foreign city is to sample the local beer.\n\n",
      categories: [],
      tags: ["München","BY","Germany","Image","Video"],
      id: 1
    });
    
  
    idx.add({
      title: "Sightseeing In Munich",
      excerpt: "Trying to visit as many sights as physically possible is sometimes worth it.\n\n",
      categories: [],
      tags: ["München","BY","Germany","Image","Photosphere","Video"],
      id: 2
    });
    
  
    idx.add({
      title: "Weird Interaction With A Local",
      excerpt: "What the hell just happened??\n\n",
      categories: [],
      tags: ["München","BY","Germany","Image"],
      id: 3
    });
    
  
    idx.add({
      title: "First Post, starring Бонифаций the cat",
      excerpt: "Here are some photos of my cat.\n\n",
      categories: [],
      tags: ["Seattle","WA","Image","Video"],
      id: 4
    });
    
  
    idx.add({
      title: "Milan - Galleria Vittorio Emanuele II",
      excerpt: "The Galleria Vittorio Emanuele II is the world’s oldest shopping mall.\n\n",
      categories: [],
      tags: ["Milano","Lombardia","Italy","Photosphere"],
      id: 5
    });
    
  
    idx.add({
      title: "MTB Adventure in Arizona",
      excerpt: "November seems to be the perfect time to visit this corner of the world.\n\n",
      categories: [],
      tags: ["Phoenix","AZ","Sedona","Lake Montezuma","Jerome","Prescott","Image","Video","Photosphere","Strava"],
      id: 6
    });
    
  
    idx.add({
      title: "In The Cold November Rain",
      excerpt: "A much-needed splash of color\n\n",
      categories: [],
      tags: ["Seattle","WA","Video","Image"],
      id: 7
    });
    
  


console.log( jQuery.type(idx) );

var store = [
  
    
    
    
      
      {
        "title": "Traveling to Munich",
        "url": "https://dtreskunov.github.io/Traveling-to-Munich/",
        "excerpt": "Bringing a 29-er mountain bike onto an airplane is usually a nerve-wracking experience. Before I get to the obvious question...",
        "teaser":
          
            null
          
      },
    
      
      {
        "title": "Munich 1",
        "url": "https://dtreskunov.github.io/munich-1/",
        "excerpt": "First order of business upon landing in a foreign city is to sample the local beer. After checking in to...",
        "teaser":
          
            null
          
      },
    
      
      {
        "title": "Sightseeing In Munich",
        "url": "https://dtreskunov.github.io/sightseeing-in-munich/",
        "excerpt": "Trying to visit as many sights as physically possible is sometimes worth it. After arriving the day before, and still...",
        "teaser":
          
            null
          
      },
    
      
      {
        "title": "Weird Interaction With A Local",
        "url": "https://dtreskunov.github.io/weird-interaction-with-a-local/",
        "excerpt": "What the hell just happened?? Germans aren’t the law-abiding sticklers they are stereotyped as. For example, they jaywalk when it...",
        "teaser":
          
            null
          
      },
    
      
      {
        "title": "First Post, starring Бонифаций the cat",
        "url": "https://dtreskunov.github.io/bonya/",
        "excerpt": "Here are some photos of my cat. His full name is Boniface (Бонифаций in Russian). He is named after the...",
        "teaser":
          
            null
          
      },
    
      
      {
        "title": "Milan - Galleria Vittorio Emanuele II",
        "url": "https://dtreskunov.github.io/milan-galleria/",
        "excerpt": "The Galleria Vittorio Emanuele II is the world’s oldest shopping mall. Housed within a four-story double arcade in central Milan,...",
        "teaser":
          
            null
          
      },
    
      
      {
        "title": "MTB Adventure in Arizona",
        "url": "https://dtreskunov.github.io/arizona/",
        "excerpt": "November seems to be the perfect time to visit this corner of the world. Catching some rays and getting a...",
        "teaser":
          
            null
          
      },
    
      
      {
        "title": "In The Cold November Rain",
        "url": "https://dtreskunov.github.io/in-the-cold-november-rain/",
        "excerpt": "A much-needed splash of color When I look into your eyes I can see a love restrained But darlin’ when...",
        "teaser":
          
            null
          
      }
    
  ]

$(document).ready(function() {
  $('input#search').on('keyup', function () {
    var resultdiv = $('#results');
    var query = $(this).val();
    var result = idx.search(query);
    resultdiv.empty();
    resultdiv.prepend('<p>'+result.length+' Result(s) found</p>');
    for (var item in result) {
      var ref = result[item].ref;
      if(store[ref].teaser){
        var searchitem =
          '<div class="list__item">'+
            '<article class="archive__item" itemscope itemtype="http://schema.org/CreativeWork">'+
              '<h2 class="archive__item-title" itemprop="headline">'+
                '<a href="'+store[ref].url+'" rel="permalink">'+store[ref].title+'</a>'+
              '</h2>'+
              '<div class="archive__item-teaser">'+
                '<img src="'+store[ref].teaser+'" alt="">'+
              '</div>'+
              '<p class="archive__item-excerpt" itemprop="description">'+store[ref].excerpt+'</p>'+
            '</article>'+
          '</div>';
      }
      else{
    	  var searchitem =
          '<div class="list__item">'+
            '<article class="archive__item" itemscope itemtype="http://schema.org/CreativeWork">'+
              '<h2 class="archive__item-title" itemprop="headline">'+
                '<a href="'+store[ref].url+'" rel="permalink">'+store[ref].title+'</a>'+
              '</h2>'+
              '<p class="archive__item-excerpt" itemprop="description">'+store[ref].excerpt+'</p>'+
            '</article>'+
          '</div>';
      }
      resultdiv.append(searchitem);
    }
  });
});
