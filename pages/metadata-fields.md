---
title: Metadata Fields
layout: about
permalink: /metadata.html
# include CollectionBuilder info at bottom
credits: false
# Edit the markdown on in this file to describe your collection
# Look in _includes/feature for options to easily add features to the page
---

# Digital Collections Metadata Fields

Iowa State University librarians utilize the following metadata fields to describe digital collections resources:

<div class="row justify-content-center py-4">
<div class="col-md-8">
<div class="table-responsive">
    <table class="table table table-striped">
        <thead>
            <tr>
                <th scope="col">Label</th>
                <th scope="col">URI</th>
                <th scope="col">Definition</th>
            </tr>
        </thead>
        <tbody>
            {% for element in site.data.cb-field-description %}
            <tr>
                <th scope="row">{{ element.cb_label}}</th>
                <td><a href="{{ element.property-uri }}">{{ element.uri }}</a></td>
                <td>{{ element.definition }}</td>
            </tr>
            {% endfor %}
        </tbody>
    </table>
</div>
</div>
</div>