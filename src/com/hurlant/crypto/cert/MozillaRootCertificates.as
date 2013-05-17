/* THIS IS A GENERATED FILE */
/**
 * MozillaRootCertificates
 *
 * A list of built-in Certificate Authorities,
 * pilfered from Mozilla. 
 *
 * See certs/tool/grabRootCAs.pl for details.
 * 
 * Copyright (c) 2007 Henri Torgemane
 * 
 * See LICENSE.txt for full license information.
 */
package com.hurlant.crypto.cert {
	public class MozillaRootCertificates extends X509CertificateCollection {
		public function MozillaRootCertificates() {
		}
		override public function addPEMCertificate(name:String,subject:String,pem:String):void {
			throw new Error("Cannot add certificates to the Root CA store.");
		}
		override public function addCertificate(cert:X509Certificate):void {
			throw new Error("Cannot add certificates to the Root CA store.");
		}
	}
}
