;; -*- mode: common-lisp; package: net.aserve -*-
;;
;; playback.cl
;;
;; copyright (c) 1986-2005 Franz Inc, Berkeley, CA  - All rights reserved.
;; copyright (c) 2000-2008 Franz Inc, Oakland, CA - All rights reserved.
;;
;; This code is free software; you can redistribute it and/or
;; modify it under the terms of the version 2.1 of
;; the GNU Lesser General Public License as published by 
;; the Free Software Foundation, as clarified by the AllegroServe
;; prequel found in license-allegroserve.txt.
;;
;; This code is distributed in the hope that it will be useful,
;; but without any warranty; without even the implied warranty of
;; merchantability or fitness for a particular purpose.  See the GNU
;; Lesser General Public License for more details.
;;
;; Version 2.1 of the GNU Lesser General Public License is in the file 
;; license-lgpl.txt that was distributed with this file.
;; If it is not present, you can access it from
;; http://www.gnu.org/copyleft/lesser.txt (until superseded by a newer
;; version) or write to the Free Software Foundation, Inc., 59 Temple Place, 
;; Suite 330, Boston, MA  02111-1307  USA
;;
;;
;; $Id: playback.cl,v 1.4 2008/02/04 21:13:16 jkf Exp $

;; Description:
;;   playback a script generated by logging a site  

;;- This code in this file obeys the Lisp Coding Standard found in
;;- http://www.franz.com/~jkf/coding_standards.html
;;-

(in-package :net.aserve)

(defvar *last-responses* nil)


(defparameter *debug-playback* nil)


(defun playback (server filename)
  (with-open-file (p filename :direction :input)
    
    (do ((form (read p nil nil) (read p nil nil))
	 (jar (make-instance 'net.aserve.client::cookie-jar)))
	((null form))
      
      (playback-form server form jar))))

(defun playback-form (server form jar)
  (macrolet ((qval (tag) `(cdr (assoc ,tag form :test #'equal))))
    (let ((method (qval :method))
	  (uri    (qval :uri))
	  (code   (qval :code))
	  (auth   (qval :auth))
	  (body   (qval :body)))
      
      
      ;; special hack to handle a few cases
      (if* (and body (match-re "user-id=" body))
	 then ; must do the hack
	      (multiple-value-bind (user-id call-id)
		  (find-user-id-etc)
		
		(if* user-id
		   then 
		  
			(setq body
			  (concatenate 'string
			    (format nil "user-id=~a&call-id=~a&~a"
				    user-id
				    call-id
				    (remove-regexp
				     "user-id=[^&]+&"
				     (remove-regexp
				      "call-id=[^&]*&"
				      body)))))
		  
			(and *debug-playback* (format t "~%~%new body ~s~%~%" body))
			)))
		  
		
			    

	      
      
      ;;
      (if* (eql 401 code)
	 then ; authorization needed
	      (format t "auth failed, skipping ~s~%" uri)
	      (return-from playback-form nil))
      (and *debug-playback* (format t "do ~s ~s~%" method uri))
      (multiple-value-bind (body retcode headers)
	  (net.aserve.client:do-http-request  
	      (format nil "~a~a" server uri)
	    :method method
	    :content (and (eq method :post)
			  body)
	    :content-type (and (eq method :post)
			       (qval :ctype))
	    :basic-authorization auth
	    :cookies jar)
	(declare (ignore headers))
	(push body *last-responses*)
	(and *debug-playback*
	     (format t "ret ~s  length(body) ~s~%" retcode (length body)))))))

	
	
(defun find-user-id-etc ()
  (dolist (resp *last-responses*)
    (multiple-value-bind (ok whole call-id)
	(match-re "name=\"call-id\" value=\"(.*?)\""
		  resp
		  :multiple-lines t
		  :case-fold t)
		
      (declare (ignore whole))
      (if* ok 
	 then (and *debug-playback* (format t "new call id is ~s~%" call-id))
	 else (and *debug-playback* (format t "No call id~%"))
	      (go out))
		
      (multiple-value-bind (ok whole user-id)
	  (match-re "name=\"user-id\" value=\"(.*?)\""
		    resp
		    :case-fold t
		    :multiple-lines t)
		  
	(declare (ignore whole))
		  
	(if* ok 
	   then (and *debug-playback* (format t "new user id is ~s~%" user-id))
	   else (and *debug-playback* (format t "No call id in ~s~%"  resp))
		(go out))
		  
	(return (values user-id call-id))))
    
    out 
    ))

	  
	  
	  
	  
	  
      
      
      


(defun remove-regexp (regexp string)
  (multiple-value-bind (ok whole before after)
      (match-re (format nil "^(.*)~a(.*)$" regexp) string)
    (declare (ignore whole))
    (if* ok
       then (concatenate 'string before after)
       else string)))

		      
