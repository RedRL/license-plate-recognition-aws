import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class QueryDbService {
  private carsUrl = `${environment.apiUrl}/cars`;
  private licensePlatesUrl = `${environment.apiUrl}/licensePlates`;
  private apiUrl = environment.apiUrl;

  constructor(private http: HttpClient) {}

  getAllCarsInfo(): Observable<any> {
    return this.http.get<any>(this.carsUrl);
  }

  getAllLicensePlates(): string[] {
    // For simplicity, assuming this returns a static list
    return ['123ABC', '456DEF', '789GHI'];
  }

  queryCars(filters: any): Observable<any[]> {
    return this.http.post<any[]>(`${this.carsUrl}/query`, filters);
  }

  getAutocompleteOptions(field: string): Observable<string[]> {
    return this.http.get<string[]>(`${this.apiUrl}/autocomplete/${field}`);
  }

  updatePlate(plateId: number, plateData: any): Observable<any> {
    return this.http.put(`${this.apiUrl}/plates/${plateId}`, plateData);
  }
}