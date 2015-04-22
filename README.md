# Html2Pdf Server

This faceless Mac application implement a server that create PDF files from HTML sources. It leverages the rendering capabilities of WebKit as a HTML rendering engine and the native Cocoa printing architecture to create PDF files.

WebKit printing is very basic and this application add many features to it allowing the creation of good looking and complex documents. See the [wiki](https://github.com/Kaviju/Html2PdfServer/wiki/Home) for the complete documentation.

## Features 

* Will never split a text line on 2 pages
* [Support of some page break control CSS attributes](https://github.com/Kaviju/Html2PdfServer/wiki/CSS-Page-break-control-attributes)
* [Vector images from SVG file](https://github.com/Kaviju/Html2PdfServer/wiki/SVG-images)
* Automatic embedding of custom fonts loaded by CSS
* Html links are functionnal in the PDF.
* [Add support for header and footer using a page template](https://github.com/Kaviju/Html2PdfServer/wiki/Page-Template)
* [Support for many paper sizes and mirror margin for document intended for duplex printing](https://github.com/Kaviju/Html2PdfServer/wiki/Paper,-margins-and-scale)
* Can create complex document by merging output from multiple html sources using different paper size, orientation or margins.


## Download

Binary releases are available in the [release section](https://github.com/Kaviju/Html2PdfServer/releases) of the project.

For server installation, see this [wiki page](https://github.com/Kaviju/Html2PdfServer/wiki/Installation-and-configuration)


## Usage

See the [wiki home](https://github.com/Kaviju/Html2PdfServer/wiki/Home) for the basic usage.

A [java class](https://github.com/Kaviju/Html2PdfServer/blob/master/SampleWebObjectsApp/Sources/html2pdfserver/sampleapp/Html2PDFService.java) for easy integration in WebObjects application is provided in the sample application.



