# Html2Pdf Server

This faceless Mac application implement a server that create PDF files from HTML sources. It leverages the rendering capabilities of WebKit as a HTML rendering engine and the native Cocoa printing architecture to create PDF files.

WebKit printing is very basic and this application add many features to it allowing the creation of good looking and complex documents. See the [wiki](https://github.com/Kaviju/Html2PdfServer/wiki/Home) for the complete documentation.

## Features 

* Will never split a text line on 2 pages
* [Support of some page break control CSS attributes](https://github.com/Kaviju/Html2PdfServer/wiki/CSS-Page-break-control-attributes)
* Allow insertion of variables like the current page number
* [Vector images from SVG file](https://github.com/Kaviju/Html2PdfServer/wiki/SVG-images)
* Automatic embedding of custom fonts loaded by CSS
* Add support for header and footer using a page template
* [Support for many paper sizes and mirror margin for document intended for duplex printing](https://github.com/Kaviju/Html2PdfServer/wiki/Paper,-margins-and-scale)
* Can create complex document by merging output from multiple html sources using differents paper size, orientation or margin.


## Download

Binary releases are available in the [release section](https://github.com/Kaviju/Html2PdfServer/releases) of the project.

For server installation, see this [wiwi page](https://github.com/Kaviju/Html2PdfServer/wiki/Installation-and-configuration)


## Usage

This server application can be used with anything able to produce HTML content. The only requireemnt is the HTML source and required resources need to be accessible from the server via url loading. The basic usage is to send a GET request with the url of the source as parameter to get back a PDF file of the rendered source.

For exemple opening `http://localhost:1453/?url=http%3A%2F%2Fwww.apple.com` in a browser on a computer running the server with default setting will display a PDF of the apple.com home page.

