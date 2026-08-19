---
title: Google Custom Search
layout: page
permalink: /google.html
noindex: true
---

# Google Custom Search 

Use the search box below to search Digital Collection pages using Google.

<script async src="https://cse.google.com/cse.js?cx=c4bc58b37ca074f94">
</script>
<div class="gcse-search"></div>

*Please note:* Site Search is a service provided by Google. Results depend on third party indexing and may contain advertisements.
{:.alert .alert-warning}

<script>
    window.onload = function() {
        var urlParams = new URLSearchParams(window.location.search);
        var query = urlParams.get('q');
        if (query) {
            var searchBox = document.querySelector('.gsc-input');
            if (searchBox) {
                searchBox.value = query;
                var searchButton = document.querySelector('.gsc-search-button');
                if (searchButton) {
                    searchButton.click();
                }
            }
        }
    };
</script>