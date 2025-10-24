import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatCardModule } from '@angular/material/card';
import { MatInputModule } from '@angular/material/input';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { FormsModule } from '@angular/forms';
import { UploadImageService } from '../../services/upload-image-service';

@Component({
  selector: 'app-upload-image',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    MatButtonModule,
    MatIconModule,
    MatCardModule,
    MatInputModule,
    MatFormFieldModule,
    MatProgressBarModule
  ],
  templateUrl: './upload-image.component.html',
  styleUrl: './upload-image.component.scss'
})
export class UploadImageComponent {
  selectedFile: File | null = null;
  uploading = false;
  result: { plate: string; make: string | null; model: string | null; color: string | null } | null = null;
  errorMessage: string | null = null;

  constructor(private uploadImageService: UploadImageService) { }

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input?.files?.length) {
      this.selectedFile = input.files[0];
    }
  }

  onDragOver(event: DragEvent): void {
    event.preventDefault();
  }

  onDrop(event: DragEvent): void {
    event.preventDefault();
    if (event.dataTransfer?.files?.length) {
      this.selectedFile = event.dataTransfer.files[0];
    }
  }

  onUpload(): void {
    if (this.selectedFile) {
      this.uploading = true;
      this.result = null;
      this.errorMessage = null;
      this.uploadImageService.uploadImage(this.selectedFile).subscribe({
        next: (res) => {
          console.log('Upload success response:', res);
          
          // Check if async processing (202 status)
          if (res?.status === 'processing') {
            // Async mode: poll for results
            console.log('Async processing - polling for results...');
            this.pollForResults(res.timestamp, res.key);
          } else {
            // Synchronous result - display immediately
            this.uploading = false;
            this.result = {
              plate: res?.plate ?? 'UNKNOWN',
              make: res?.make ?? null,
              model: res?.model ?? null,
              color: res?.color ?? null
            };
          }
        },
        error: (err) => {
          console.error('Upload error response:', err);
          this.uploading = false;
          this.errorMessage = err?.error?.error ?? 'Upload or recognition failed.';
        }
      });
    }
  }

  private pollForResults(timestamp: string, key: string, maxAttempts: number = 60): void {
    let attempts = 0;
    const pollInterval = 2000; // Poll every 2 seconds
    
    const poll = () => {
      attempts++;
      console.log(`Polling attempt ${attempts}/${maxAttempts} for timestamp: ${timestamp}`);
      
      // Query database for the most recent record (should be our upload)
      const queryDate = timestamp.split('T')[0]; // Get just the date part
      
      this.uploadImageService.queryDatabase({
        licensePlates: [],
        colors: [],
        makes: [],
        models: [],
        queryDate: queryDate
      }).subscribe({
        next: (results: any[]) => {
          console.log('Poll results:', results);
          
          // Find our result by timestamp (get most recent)
          if (results && results.length > 0) {
            const latestResult = results[0]; // Results are ordered by timestamp DESC
            
            // Check if this is recent enough (within last minute)
            const resultTime = new Date(latestResult.time);
            const uploadTime = new Date(timestamp);
            const timeDiff = Math.abs(resultTime.getTime() - uploadTime.getTime());
            
            if (timeDiff < 120000) { // Within 2 minutes
              // Found our result!
              console.log('Found result:', latestResult);
              this.uploading = false;
              this.result = {
                plate: latestResult.licensePlate ?? 'UNKNOWN',
                make: latestResult.make ?? null,
                model: latestResult.model ?? null,
                color: latestResult.color ?? null
              };
              return; // Stop polling
            }
          }
          
          // No result yet - keep polling if attempts remaining
          if (attempts < maxAttempts) {
            setTimeout(poll, pollInterval);
          } else {
            // Timeout after maxAttempts
            console.log('Polling timeout - no results found');
            this.uploading = false;
            this.errorMessage = '⏱️ Processing is taking longer than expected. Please check "Query Database" page.';
          }
        },
        error: (err) => {
          console.error('Polling error:', err);
          // Keep trying unless we've exceeded max attempts
          if (attempts < maxAttempts) {
            setTimeout(poll, pollInterval);
          } else {
            this.uploading = false;
            this.errorMessage = 'Failed to retrieve results. Please check "Query Database" page.';
          }
        }
      });
    };
    
    // Start polling after a short delay (give worker time to start processing)
    setTimeout(poll, 3000); // Wait 3 seconds before first poll
  }
}
