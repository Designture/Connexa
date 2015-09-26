class TransportException extends Exception {

  /**
   * Error message
   */
  String message;

  /**
   * Error description
   */
  String description;

  /**
   * Constructor
   */
  TransportException(this.message, [this.description = '']);

}